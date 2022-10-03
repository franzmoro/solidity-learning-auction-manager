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
      this.DropMinterContract.connect(this.addr1).mint(this.addr1.address, "1")
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

  it("allows authorized contract to mint", async function () {
    await this.DropMinterContract.setAuthorizer(this.addr1.address);

    const balanceBeforeMint = await this.DropMinterContract.balanceOf(
      this.addr2.address
    );
    expect(balanceBeforeMint.toNumber()).to.equal(0);

    await this.DropMinterContract.connect(this.addr1).mint(
      this.addr2.address,
      "1000"
    );

    const balanceAfterMint = await this.DropMinterContract.balanceOf(
      this.addr2.address
    );
    expect(balanceAfterMint.toNumber()).to.equal(1);

    expect(await this.DropMinterContract.ownerOf("1000")).to.equal(
      this.addr2.address
    );
  });
});

describe.skip("Integration tests - AuctionManager + Minter", async function () {
  beforeEach(async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    this.owner = owner;
    this.addr1 = addr1;
    this.addr2 = addr2;

    this.startingPrice = ethers.utils.parseEther("0.05");
    this.endTimeOffset = 50;

    this.dropId = 3;

    this.DropMinterContract = await deployContract("DropMinter", []);

    this.AuctionManager = await deployContract("AuctionManager", [
      (this.DropMinterContract as Contract).address,
    ]);

    await this.AuctionManager.createAuction(
      this.dropId,
      this.endTimeOffset,
      this.startingPrice
    );

    this.fastForwardToEnd = async function () {
      await network.provider.send("evm_increaseTime", [
        this.endTimeOffset + 20,
      ]);
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
    await expect(
      this.AuctionManager.connect(this.addr1).getPrize(this.dropId)
    ).revertedWith("Unauthorized");
  });

  it("should allow AuctionManager to call Minter contract if authorized", async function () {
    // set permission to AuctionManager to mint
    await this.DropMinterContract.setAuthorizer(this.AuctionManager.address);

    // addr1 bids
    await this.AuctionManager.connect(this.addr1).bid({
      value: ethers.utils.parseEther("0.5"),
    });

    // end of auction
    await this.fastForwardToEnd();

    // bid winner calls `getPrize`
    await this.AuctionManager.connect(this.addr1).getPrize("1000");

    expect(await this.DropMinterContract.ownerOf("1000")).to.equal(
      this.addr1.address
    );
  });
});

// TODO: test where the AuctionManager is set as the authorized minter
