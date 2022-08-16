import { ethers, network } from "hardhat";
import { BigNumber } from "ethers";
import { assert, expect } from "chai";
import deployContract from "./helpers/deployContract";

describe("AuctionManager", function () {
  beforeEach(async function () {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    this.startingPrice = ethers.utils.parseEther("0.05");
    this.endTimeOffset = 50;

    this.auction = await deployContract("AuctionManager", [
      this.startingPrice,
      this.endTimeOffset,
    ]);

    this.owner = owner;
    this.addr1 = addr1;
    this.addr2 = addr2;
    this.addr3 = addr3;

    this.fastForwardToEnd = async function () {
      await network.provider.send("evm_increaseTime", [
        this.endTimeOffset + 20,
      ]);
      await network.provider.send("evm_mine");
    };
  });

  describe("getBid()", function () {
    it("should return 0 if user has not bid", async function () {
      expect(
        await this.auction
          .connect(this.addr1.address)
          .getBid(this.addr1.address)
      ).to.be.equal(0);
    });
  });

  describe("bid()", function () {
    it("should save initial user bid", async function () {
      const bidAmount = ethers.utils.parseEther("0.1");

      await this.auction.connect(this.addr1).bid({ value: bidAmount });

      const currentUserBid = await this.auction
        .connect(this.addr1.address)
        .getBid(this.addr1.address);

      expect(currentUserBid).to.be.equal(bidAmount);
    });

    it("should not allow bids below startingPrice", async function () {
      const bidAmount = ethers.utils.parseEther("0.001");

      await expect(
        this.auction.connect(this.addr1).bid({ value: bidAmount })
      ).revertedWith("Must be higher than startingPrice");
    });

    it("should use user's funds for bid", async function () {
      const bidAmount = ethers.utils.parseEther("0.1");
      const originalUserBalance = await ethers.provider.getBalance(
        this.addr1.address
      );

      await this.auction.connect(this.addr1).bid({ value: bidAmount });

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
        .bid({ value: ethers.utils.parseEther("0.2") });

      await expect(
        this.auction
          .connect(this.addr2)
          .bid({ value: ethers.utils.parseEther("0.1") })
      ).revertedWith("Must outbid current highest bid");
    });

    it("should replace previous highest bid if new bid exceeds it", async function () {
      const bidAmount1 = ethers.utils.parseEther("0.1");
      const bidAmount2 = ethers.utils.parseEther("0.2");

      await this.auction.connect(this.addr1).bid({ value: bidAmount1 });
      await this.auction.connect(this.addr2).bid({ value: bidAmount2 });

      expect(await this.auction.highestBid()).to.equal(bidAmount2);
    });

    it("should allow users to increase their bid if exceeds highest bid", async function () {
      const bidAmount1 = ethers.utils.parseEther("0.1");
      await this.auction.connect(this.addr1).bid({ value: bidAmount1 });

      const newHighestBid = ethers.utils.parseEther("0.2");
      await this.auction.connect(this.addr2).bid({ value: newHighestBid });

      const increaseBidAmount = ethers.utils.parseEther("0.2");
      await this.auction.connect(this.addr1).bid({ value: increaseBidAmount });

      const highestBid = await this.auction.highestBid();
      const userBid = await this.auction.getBid(this.addr1.address);

      assert(userBid.eq(bidAmount1.add(increaseBidAmount)));
      assert(highestBid.eq(userBid));
    });

    it("should allow users to increase their bid if exceeds highest bid", async function () {
      const bidAmount1 = ethers.utils.parseEther("0.1");
      await this.auction.connect(this.addr1).bid({ value: bidAmount1 });

      const newHighestBid = ethers.utils.parseEther("0.2");
      await this.auction.connect(this.addr2).bid({ value: newHighestBid });

      const increaseBidAmount = ethers.utils.parseEther("0.05");
      await expect(
        this.auction.connect(this.addr1).bid({ value: increaseBidAmount })
      ).revertedWith("Must outbid current highest bid");

      const highestBid = await this.auction.highestBid();
      const userBid = await this.auction.getBid(this.addr1.address);

      assert(userBid.eq(bidAmount1));
      assert(highestBid.eq(newHighestBid));
    });
  });

  describe("getHighestBid()", function () {
    it("should return 0 if no bids", async function () {
      expect(await this.auction.highestBid()).to.equal(0);
    });

    it("should return current highest bid. initial bid only", async function () {
      const bidAmount = ethers.utils.parseEther("0.1");

      await this.auction.connect(this.addr1).bid({ value: bidAmount });

      expect(await this.auction.highestBid()).to.equal(bidAmount);
    });
  });

  context("auction ending", function () {
    it("should still allow user to bid if before the auction's end", async function () {
      await network.provider.send("evm_increaseTime", [
        this.endTimeOffset - 10,
      ]);
      await network.provider.send("evm_mine");

      const bidAmount = ethers.utils.parseEther("0.5");
      await this.auction.connect(this.addr1).bid({ value: bidAmount });

      expect(await this.auction.highestBid()).to.equal(bidAmount);
    });

    it("should not allow further bids at auction's end", async function () {
      await this.fastForwardToEnd();

      await expect(
        this.auction
          .connect(this.addr1)
          .bid({ value: ethers.utils.parseEther("0.5") })
      ).revertedWith("Auction ended");
    });

    it("should keep winning bidder's funds on bid end", async function () {
      const bidAmount = ethers.utils.parseEther("0.25");
      await this.auction.connect(this.addr1).bid({ value: bidAmount });

      await this.fastForwardToEnd();

      expect(await this.auction.highestBid()).to.equal(bidAmount);
    });
  });

  context("withdraw", function () {
    it("should revert if auction is not ended", async function () {
      await this.auction
        .connect(this.addr1)
        .bid({ value: ethers.utils.parseEther("0.25") });

      await expect(this.auction.connect(this.addr1).withdraw()).revertedWith(
        "Auction not ended"
      );
    });

    it("should not allow winner to withdraw", async function () {
      await this.auction
        .connect(this.addr1)
        .bid({ value: ethers.utils.parseEther("0.25") });

      await this.auction
        .connect(this.addr2)
        .bid({ value: ethers.utils.parseEther("0.55") });

      await this.fastForwardToEnd();

      await expect(this.auction.connect(this.addr2).withdraw()).revertedWith(
        "winner cannot withdraw"
      );
    });

    it("should allow losers to withdraw", async function () {
      await this.auction
        .connect(this.addr1)
        .bid({ value: ethers.utils.parseEther("0.25") });

      await this.auction
        .connect(this.addr2)
        .bid({ value: ethers.utils.parseEther("0.55") });

      await this.auction
        .connect(this.addr3)
        .bid({ value: ethers.utils.parseEther("0.75") });

      await this.fastForwardToEnd();

      const user1BalancePreWithdraw = await ethers.provider.getBalance(
        this.addr1.address
      );
      const user2BalancePreWithdraw = await ethers.provider.getBalance(
        this.addr2.address
      );
      await this.auction.connect(this.addr1).withdraw({ value: 0 });
      await this.auction.connect(this.addr2).withdraw({ value: 0 });

      assert(
        (await ethers.provider.getBalance(this.addr1.address)).gt(
          user1BalancePreWithdraw
        )
      );
      assert(
        (await ethers.provider.getBalance(this.addr2.address)).gt(
          user2BalancePreWithdraw
        )
      );
    });

    it("should not allow user to withdraw twice", async function () {
      await this.auction
        .connect(this.addr1)
        .bid({ value: ethers.utils.parseEther("0.25") });

      await this.auction
        .connect(this.addr2)
        .bid({ value: ethers.utils.parseEther("0.55") });

      await this.fastForwardToEnd();

      await this.auction.connect(this.addr1).withdraw();

      await expect(this.auction.connect(this.addr1).withdraw()).revertedWith(
        "no funds to withdraw"
      );
    });

    it("should not allow non-bidding users to spam", async function () {
      await this.auction
        .connect(this.addr1)
        .bid({ value: ethers.utils.parseEther("0.2") });

      await this.fastForwardToEnd();

      await expect(this.auction.connect(this.addr2).withdraw()).revertedWith(
        "no funds to withdraw"
      );
    });
  });
});
