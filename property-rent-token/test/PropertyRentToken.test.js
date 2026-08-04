const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PropertyRentToken", function () {
  let propertyToken, usdc, admin, oracle, investorA, investorB;

  beforeEach(async function () {
    [admin, investorA, investorB] = await ethers.getSigners();

    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    usdc = await MockUSDC.deploy();

    const PropertyRentToken = await ethers.getContractFactory("PropertyRentToken");
    propertyToken = await PropertyRentToken.deploy(
      "Edificio Calle Mayor 4",
      "ECM4",
      admin.address,
      await usdc.getAddress()
    );
  });

  it("mintea el supply fijo completo al admin en el deploy", async function () {
    const totalSupply = await propertyToken.totalSupply();
    expect(await propertyToken.balanceOf(admin.address)).to.equal(totalSupply);
    expect(totalSupply).to.equal(ethers.parseUnits("50000", 18));
  });

  it("distribuye la renta proporcionalmente entre dos holders", async function () {
    const half = ethers.parseUnits("25000", 18);
    await propertyToken.transfer(investorA.address, half);
    await propertyToken.transfer(investorB.address, half);

    const rentAmount = ethers.parseUnits("2000", 18);
    await usdc.approve(await propertyToken.getAddress(), rentAmount);
    await propertyToken.depositRent(rentAmount);
    await propertyToken.reportRentIncome(
      rentAmount - (rentAmount * 2n) / 100n, // neto, ya sin el 2% de fee
      1
    );

    await propertyToken.connect(investorA).claimRent();
    await propertyToken.connect(investorB).claimRent();

    const balanceA = await usdc.balanceOf(investorA.address);
    const balanceB = await usdc.balanceOf(investorB.address);

    expect(balanceA).to.equal(balanceB);
  });

  it("revierte si se reporta el mismo periodo dos veces", async function () {
    const rentAmount = ethers.parseUnits("2000", 18);
    await usdc.approve(await propertyToken.getAddress(), rentAmount);
    await propertyToken.depositRent(rentAmount);
    await propertyToken.reportRentIncome(rentAmount, 1);

    await expect(
      propertyToken.reportRentIncome(rentAmount, 1)
    ).to.be.revertedWith("period already reported");
  });

  it("revierte si updatePrice supera el circuit breaker del 10%", async function () {
    await expect(
      propertyToken.updatePrice(120) // +20% sobre el precio inicial de 100
    ).to.be.revertedWith("price increase exceeds max delta");
  });
});
