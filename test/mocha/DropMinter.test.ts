import { expect } from "chai";
import { Contract } from "ethers";
import { ethers, network } from "hardhat";
import deployContract from "./helpers/deployContract";

describe("DropMinter", function () {
  beforeEach(async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    this.DropMinterContract = await deployContract("DropMinter", []);
    this.owner = owner;
    this.addr1 = addr1;
    this.addr2 = addr2;
  });

  describe("permissions", function () {
    it("does not allow non-owners to set baseURI", async function () {
      await expect(
        this.DropMinterContract.connect(this.addr1).setBaseURI(
          "http://scam-nft.rug"
        )
      ).revertedWith("Ownable: caller is not the owner");
    });

    it("allows owner to set baseURI", async function () {
      await this.DropMinterContract.setBaseURI("http://new.api.com");
    });

    it("does not allow external address to mint", async function () {
      await expect(
        this.DropMinterContract.connect(this.addr1).mint(
          this.addr1.address,
          "1"
        )
      ).revertedWith("Unauthorized");
    });

    it("does not allow non-owner to set authorized minter", async function () {
      await expect(
        this.DropMinterContract.connect(this.addr1).setAuthorizer(
          this.addr1.address
        )
      ).revertedWith("Ownable: caller is not the owner");
    });

    it("allows owner to set authorized minter", async function () {
      await this.DropMinterContract.setAuthorizer(this.addr1.address);
      const authorizedOwner = await this.DropMinterContract.authorizedMinter();
      expect(authorizedOwner).to.equal(this.addr1.address);
    });

    it("does not allow non-authorized minter to createDrop", async function () {
      await expect(this.DropMinterContract.setMaxSupply(1, 100)).revertedWith(
        "Unauthorized"
      );
    });
  });

  describe("maxSupply()", function () {
    it("should return 0 for non-existing drops", async function () {
      expect(await this.DropMinterContract.maxSupply(1)).to.equal(0);
    });
  });

  describe("createDrop()", function () {
    it("allows authorized contract to create drop", async function () {
      const dropId = 1;

      await this.DropMinterContract.setAuthorizer(this.owner.address);
      await this.DropMinterContract.createDrop(10);

      expect(await this.DropMinterContract.maxSupply(dropId)).to.equal(10);
    });
  });

  describe("mint()", function () {
    it("allows authorized contract to mint", async function () {
      const dropId = 1;

      await this.DropMinterContract.setAuthorizer(this.owner.address);
      await this.DropMinterContract.createDrop(10);

      expect(await this.DropMinterContract.maxSupply(dropId)).to.equal(10);

      const balanceBeforeMint = await this.DropMinterContract.balanceOf(
        this.addr2.address
      );
      expect(balanceBeforeMint.toNumber()).to.equal(0);

      await this.DropMinterContract.mint(this.addr2.address, dropId);

      const balanceAfterMint = await this.DropMinterContract.balanceOf(
        this.addr2.address
      );
      expect(balanceAfterMint.toNumber()).to.equal(1);

      expect(await this.DropMinterContract.ownerOf("10000")).to.equal(
        this.addr2.address
      );

      expect(await this.DropMinterContract.maxSupply(dropId)).to.equal(10);
      expect(await this.DropMinterContract.circulating(dropId)).to.equal(1);
    });
  });

  describe("maxSupply()", function () {
    it("should return 0 for non-existing drops", async function () {
      expect(await this.DropMinterContract.maxSupply(1)).to.equal(0);
    });

    it("should return created drop maxSupply", async function () {
      await this.DropMinterContract.setAuthorizer(this.owner.address);

      await this.DropMinterContract.createDrop(100);
      const dropId = 1;
      expect(await this.DropMinterContract.maxSupply(dropId)).to.equal(100);
    });
  });

  describe("setMaxSupply()", function () {
    // TODO: prevent setting max supply without drop being created first

    it("sets maxSupply for an existing drop", async function () {
      await this.DropMinterContract.setAuthorizer(this.owner.address);
      await this.DropMinterContract.createDrop(100);
      const dropId = 1;
      expect(await this.DropMinterContract.maxSupply(dropId)).to.equal(100);

      await this.DropMinterContract.setMaxSupply(dropId, 50);
      expect(await this.DropMinterContract.maxSupply(dropId)).to.equal(50);
    });
  });
});

describe("Integration tests - AuctionManager + Minter", async function () {
  beforeEach(async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    this.owner = owner;
    this.addr1 = addr1;
    this.addr2 = addr2;

    this.startingPrice = ethers.utils.parseEther("0.05");
    this.startTimeOffset = 50;
    this.endTimeOffset = 500;

    this.dropId = 1;

    this.DropMinterContract = await deployContract("DropMinter", []);

    this.AuctionManager = await deployContract("AuctionManager", [
      (this.DropMinterContract as Contract).address,
    ]);

    await this.AuctionManager.setMinter(this.DropMinterContract.address);
    await this.DropMinterContract.setAuthorizer(this.AuctionManager.address);

    await this.AuctionManager.createAuction(
      this.startTimeOffset,
      this.endTimeOffset,
      this.startingPrice
    );

    // fast forward to auction start
    await network.provider.send("evm_increaseTime", [this.startTimeOffset + 1]);
    await network.provider.send("evm_mine");

    this.fastForwardToEnd = async function () {
      await network.provider.send("evm_increaseTime", [this.endTimeOffset + 1]);
      await network.provider.send("evm_mine");
    };
  });

  it("should not allow AuctionManager to call Minter contract if not authorized", async function () {
    // addr1 bids
    await this.AuctionManager.connect(this.addr1).bid(this.dropId, {
      value: ethers.utils.parseEther("0.5"),
    });
    // end of auction
    await this.fastForwardToEnd();
    // bid winner calls `getPrize`
    await this.DropMinterContract.setAuthorizer(this.addr2.address);

    await expect(
      this.AuctionManager.connect(this.addr1).getPrize(this.dropId)
    ).revertedWith("Unauthorized");
  });

  it("should allow AuctionManager to call Minter contract if authorized", async function () {
    // addr1 bids
    await this.AuctionManager.connect(this.addr1).bid(this.dropId, {
      value: ethers.utils.parseEther("0.5"),
    });

    // end of auction
    await this.fastForwardToEnd();

    // bid winner calls `getPrize`
    await this.AuctionManager.connect(this.addr1).getPrize(this.dropId);

    expect(await this.DropMinterContract.ownerOf(10000)).to.equal(
      this.addr1.address
    );
  });
});
