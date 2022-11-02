import { ethers, network } from "hardhat";
import { BigNumber } from "ethers";
import { assert, expect } from "chai";
import deployContract from "./helpers/deployContract";

describe("AuctionManager", function () {
  beforeEach(async function () {
    const [owner, addr1, addr2, addr3, mintingContractAddress] =
      await ethers.getSigners();

    this.startingPrice = ethers.utils.parseEther("0.05");
    this.startTimeOffset = 50;
    this.endTimeOffset = 500;
    this.owner = owner;
    this.addr1 = addr1;
    this.addr2 = addr2;
    this.addr3 = addr3;
    this.mintingContractAddress = mintingContractAddress;

    this.auction = await deployContract("AuctionManager", [
      mintingContractAddress.address,
    ]);
    this.MinterContract = await deployContract("DropMinter", []);

    this.fastForwardToStart = async function () {
      await network.provider.send("evm_increaseTime", [
        this.startTimeOffset + 1,
      ]);
      await network.provider.send("evm_mine");
    };

    this.fastForwardToEnd = async function () {
      await network.provider.send("evm_increaseTime", [
        this.endTimeOffset + 500,
      ]);
      await network.provider.send("evm_mine");
    };

    this.createMockAuction = async function () {
      await this.auction.setMinter(this.MinterContract.address);
      await this.MinterContract.setAuthorizer(this.auction.address);
      await this.auction.createAuction(
        this.startTimeOffset,
        this.endTimeOffset,
        this.startingPrice
      );
    };
  });

  describe("createAuction()", function () {
    it("does not let regular users create an auction", async function () {
      await expect(
        this.auction
          .connect(this.addr1)
          .createAuction(5, 5, ethers.utils.parseEther("0.1"))
      ).revertedWith("Ownable: caller is not the owner");
    });

    it("creates an auction with supply 1", async function () {
      const dropId = 1;
      const expected = { maxSupply: 1, circulating: 0 };

      await this.auction.setMinter(this.MinterContract.address);
      await this.MinterContract.setAuthorizer(this.auction.address);

      expect(await this.auction.dropType(dropId)).to.equal(0);

      await this.auction.createAuction(5, 5, ethers.utils.parseEther("0.1"));

      expect(await this.auction.dropType(dropId)).to.equal(1);

      expect(await this.MinterContract.maxSupply(dropId)).to.equal(
        expected.maxSupply
      );
      expect(await this.MinterContract.circulating(dropId)).to.equal(
        expected.circulating
      );
    });
  });

  // TODO: createFixedPriceDrop

  describe("highestBid()", function () {
    it("should return 0 if user has not bid", async function () {
      await this.createMockAuction();
      const dropId = 1;

      expect(
        await this.auction.connect(this.addr1).highestBid(dropId)
      ).to.be.equal(0);
    });
  });

  describe("bid()", function () {
    beforeEach(async function () {
      await this.createMockAuction();
      this.dropId = 1;
    });

    it("should not let user bid if auction not set", async function () {
      await expect(
        this.auction
          .connect(this.addr1)
          .bid(this.dropId + 10, { value: ethers.utils.parseEther("0.1") })
      ).revertedWith("Auction not found");
    });

    it("should not let user bid if auction not started", async function () {
      await expect(
        this.auction
          .connect(this.addr1)
          .bid(this.dropId, { value: ethers.utils.parseEther("0.1") })
      ).revertedWith("Auction not started");
    });

    context("Auction has started", function () {
      beforeEach(async function () {
        await this.fastForwardToStart();
      });

      it("should save initial user bid", async function () {
        const bidAmount = ethers.utils.parseEther("0.1");

        await this.auction
          .connect(this.addr1)
          .bid(this.dropId, { value: bidAmount });

        const currentUserBid = await this.auction
          .connect(this.addr1)
          .highestBid(this.dropId);

        expect(currentUserBid).to.be.equal(bidAmount);
      });

      it("should not allow bids below startingPrice", async function () {
        await expect(
          this.auction
            .connect(this.addr1)
            .bid(this.dropId, { value: ethers.utils.parseEther("0.0001") })
        ).revertedWith("must be gt starting price");
      });

      it("should use user's funds for bid", async function () {
        const bidAmount = ethers.utils.parseEther("0.1");
        const originalUserBalance = await ethers.provider.getBalance(
          this.addr1.address
        );

        await this.auction
          .connect(this.addr1)
          .bid(this.dropId, { value: bidAmount });

        const userBalanceAfterBid = await ethers.provider.getBalance(
          this.addr1.address
        );

        // it will be less, due to gas fee
        assert(
          userBalanceAfterBid.lte(
            originalUserBalance.sub(BigNumber.from(bidAmount))
          )
        );
      });

      it("should not allow bid if lower than highest bid", async function () {
        await this.auction
          .connect(this.addr1)
          .bid(this.dropId, { value: ethers.utils.parseEther("0.2") });

        await expect(
          this.auction
            .connect(this.addr2)
            .bid(this.dropId, { value: ethers.utils.parseEther("0.1") })
        ).revertedWith("must be gt highest bid");
      });

      it("should replace previous highest bid if new bid exceeds it", async function () {
        const bidAmount1 = ethers.utils.parseEther("0.1");
        const bidAmount2 = ethers.utils.parseEther("0.2");

        await this.auction
          .connect(this.addr1)
          .bid(this.dropId, { value: bidAmount1 });

        await this.auction
          .connect(this.addr2)
          .bid(this.dropId, { value: bidAmount2 });

        expect(await this.auction.highestBid(this.dropId)).to.equal(bidAmount2);
      });

      it("should allow users to outbid previous highest bid", async function () {
        const bidAmount1 = ethers.utils.parseEther("0.1");
        await this.auction
          .connect(this.addr1)
          .bid(this.dropId, { value: bidAmount1 });

        const newHighestBid = ethers.utils.parseEther("0.2");
        await this.auction
          .connect(this.addr2)
          .bid(this.dropId, { value: newHighestBid });

        const newBid = ethers.utils.parseEther("0.3");
        await this.auction
          .connect(this.addr1)
          .bid(this.dropId, { value: newBid });

        const highestBid = await this.auction.highestBid(this.dropId);

        assert(highestBid.eq(newBid));
      });

      it("should not allow users to place bid if equal to highest bid", async function () {
        const bidAmount1 = ethers.utils.parseEther("0.1");
        await this.auction
          .connect(this.addr1)
          .bid(this.dropId, { value: bidAmount1 });

        const newHighestBid = ethers.utils.parseEther("0.2");
        await this.auction
          .connect(this.addr2)
          .bid(this.dropId, { value: newHighestBid });

        const increaseBidAmount = ethers.utils.parseEther("0.2");
        await expect(
          this.auction
            .connect(this.addr1)
            .bid(this.dropId, { value: increaseBidAmount })
        ).revertedWith("must be gt highest bid");

        const highestBid = await this.auction.highestBid(this.dropId);
        assert(highestBid.eq(newHighestBid));
      });
    });
  });

  describe("getHighestBid()", function () {
    beforeEach(async function () {
      await this.createMockAuction();
      this.dropId = 1;
    });

    it("should return 0 if no bids", async function () {
      expect(await this.auction.highestBid(this.dropId)).to.equal(0);
    });

    it("should return current highest bid. initial bid only", async function () {
      const bidAmount = ethers.utils.parseEther("0.1");
      await this.fastForwardToStart();

      await this.auction
        .connect(this.addr1)
        .bid(this.dropId, { value: bidAmount });

      expect(await this.auction.highestBid(this.dropId)).to.equal(bidAmount);
    });
  });

  describe("auction ending", function () {
    beforeEach(async function () {
      await this.createMockAuction();
      await this.fastForwardToStart();

      this.dropId = 1;
    });

    it("should not allow further bids at auction's end", async function () {
      await this.fastForwardToEnd();

      await expect(
        this.auction
          .connect(this.addr1)
          .bid(this.dropId, { value: ethers.utils.parseEther("0.5") })
      ).revertedWith("Auction ended");
    });

    it("should keep winning bidder's funds on bid end", async function () {
      const bidAmount = ethers.utils.parseEther("0.25");
      await this.auction
        .connect(this.addr1)
        .bid(this.dropId, { value: bidAmount });

      const balanceBeforeEnd = await ethers.provider.getBalance(
        this.addr1.address
      );

      await this.fastForwardToEnd();

      const balanceAtEnd = await ethers.provider.getBalance(this.addr1.address);

      expect(await this.auction.highestBid(this.dropId)).to.equal(bidAmount);
      expect(balanceAtEnd).to.equal(balanceBeforeEnd);
    });
  });

  describe("Integration test - winner get prize", function () {
    beforeEach(async function () {
      await this.createMockAuction();
      await this.fastForwardToStart();

      this.dropId = 1;
    });

    it("should allow winner to get prize", async function () {
      await this.auction
        .connect(this.addr1)
        .bid(this.dropId, { value: ethers.utils.parseEther("0.25") });

      await this.fastForwardToEnd();

      await this.auction.connect(this.addr1).getPrize(this.dropId);

      const tokenId = 10000;
      expect(await this.MinterContract.ownerOf(tokenId)).to.equal(
        this.addr1.address
      );
    });

    it("should not allow non-winners to get prize", async function () {
      // user 1 bids low
      await this.auction
        .connect(this.addr1)
        .bid(this.dropId, { value: ethers.utils.parseEther("0.15") });

      // user 2 bids higher
      await this.auction
        .connect(this.addr2)
        .bid(this.dropId, { value: ethers.utils.parseEther("0.25") });

      await this.fastForwardToEnd();

      // user 1 tries to get prize, but cannot
      await expect(
        this.auction.connect(this.addr1).getPrize(this.dropId)
      ).revertedWith("not the winner");

      // user 2 can still get prize
      await this.auction.connect(this.addr2).getPrize(this.dropId);
      expect(await this.MinterContract.ownerOf(10000)).to.equal(
        this.addr2.address
      );
      expect(await this.MinterContract.balanceOf(this.addr2.address)).to.equal(
        1
      );
    });

    it("should not allow winner to get prize more than once", async function () {
      await this.auction
        .connect(this.addr1)
        .bid(this.dropId, { value: ethers.utils.parseEther("0.25") });

      await this.fastForwardToEnd();

      await this.auction.connect(this.addr1).getPrize(this.dropId);

      expect(await this.MinterContract.ownerOf(10000)).to.equal(
        this.addr1.address
      );
      expect(await this.MinterContract.balanceOf(this.addr1.address)).to.equal(
        1
      );

      await expect(
        this.auction.connect(this.addr1).getPrize(this.dropId)
      ).revertedWith("Already got prize");
    });
  });
});
