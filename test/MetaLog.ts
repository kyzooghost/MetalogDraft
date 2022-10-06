// import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
// import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { MetaLog, MathLibraryTest } from '../typechain-types';
import { BigNumber as BN } from 'ethers';
import { SCALE } from '@prb/math';

// https://docs.google.com/spreadsheets/d/1pBq1jnpRsFPQROkk3lpfFHi4Km-GUKxnZbeWocly1T8/edit#gid=1647682004

describe('MetaLog', function () {
  let metaLog: MetaLog;
  let test: MathLibraryTest;

  const ZERO: BN = BN.from('0');
  const HALF: BN = BN.from('10').pow(17).mul(5);
  const ONE: BN = BN.from('10').pow(18).mul(1);
  const TWO: BN = BN.from('10').pow(18).mul(2);
  const THREE: BN = BN.from('10').pow(18).mul(3);
  const FOUR: BN = BN.from('10').pow(18).mul(4);
  const EIGHT: BN = BN.from('10').pow(18).mul(8);
  const e: BN = BN.from('2718281828459045235');
  const SCALE_FACTOR = ONE;

  2.7182818284;

  before(async () => {
    const [owner, otherAccount] = await ethers.getSigners();
    const MetaLog = await ethers.getContractFactory('MetaLog');
    const Test = await ethers.getContractFactory('MathLibraryTest');
    metaLog = await MetaLog.deploy();
    test = await Test.deploy();
  });

  describe('Test PRBMathSD59x18 library for int256 operations', function () {
    it('mul', async function () {
      expect(await test.mul(ONE, ONE)).eq(ONE);
      expect(await test.mul(ONE, TWO)).eq(TWO);
      expect(await test.mul(ONE, HALF)).eq(HALF);
      expect(await test.mul(FOUR, HALF)).eq(TWO);
      expect(await test.mul(ONE, ONE.mul(-1))).eq(ONE.mul(-1));
      expect(await test.mul(ONE.mul(-1), ONE.mul(-1))).eq(ONE);
    });

    it('div', async function () {
      expect(await test.div(ONE, ONE)).eq(ONE);
      expect(await test.div(ONE, TWO)).eq(HALF);
      expect(await test.div(TWO, ONE)).eq(TWO);
      expect(await test.div(FOUR, HALF)).eq(EIGHT);
      expect(await test.div(ONE, ONE.mul(-1))).eq(ONE.mul(-1));
      expect(await test.div(ONE.mul(-1), ONE.mul(-1))).eq(ONE);
    });

    it('inv', async function () {
      expect(await test.inv(ONE)).eq(ONE);
      expect(await test.inv(TWO)).eq(HALF);
      expect(await test.inv(HALF)).eq(TWO);
      expect(await test.inv(ONE.mul(-1))).eq(ONE.mul(-1));
    });

    it('exp', async function () {
      expectWithinErrorBPS(await test.exp(ONE), e, 1);
      expectWithinErrorBPS(await test.exp(TWO), e.pow(2).div(SCALE), 1);
      expectWithinErrorBPS(await test.exp(FOUR), e.pow(4).div(SCALE).div(SCALE).div(SCALE), 1);
      expectWithinErrorBPS(await test.exp(ONE.mul(-1)), ONE.mul(ONE).div(e), 1);

    });

    it('ln', async function () {
      expect(await test.ln(ONE)).eq(ZERO);
      expectWithinErrorBPS(await test.ln(e), ONE, 1);
      expectWithinErrorBPS(await test.ln(EIGHT), BN.from("2079441541679835928"), 1);
    });

    it('pow', async function () {
      expect(await test.pow(ONE, TWO)).eq(ONE);
      expect(await test.pow(ONE, EIGHT)).eq(ONE);
      expect(await test.pow(TWO, TWO)).eq(FOUR);
      expect(await test.pow(TWO, THREE)).eq(EIGHT);
      expect(await test.pow(TWO, ONE.mul(-1))).eq(await test.inv(TWO));
      expect(await test.pow(TWO, TWO.mul(-1))).eq(await test.mul(HALF, HALF));
    });
  });

  describe('Nine-term metalog ', function () {
    // it("Should set the right unlockTime", async function () {
    // console.log("Hello");
    // });
  });

  // describe("Withdrawals", function () {
  //   describe("Validations", function () {
  //     it("Should revert with the right error if called too soon", async function () {
  //       const { lock } = await loadFixture(deployOneYearLockFixture);

  //       await expect(lock.withdraw()).to.be.revertedWith(
  //         "You can't withdraw yet"
  //       );
  //     });

  //     it("Should revert with the right error if called from another account", async function () {
  //       const { lock, unlockTime, otherAccount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       // We can increase the time in Hardhat Network
  //       await time.increaseTo(unlockTime);

  //       // We use lock.connect() to send a transaction from another account
  //       await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
  //         "You aren't the owner"
  //       );
  //     });

  //     it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
  //       const { lock, unlockTime } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       // Transactions are sent using the first signer by default
  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).not.to.be.reverted;
  //     });
  //   });

  //   describe("Events", function () {
  //     it("Should emit an event on withdrawals", async function () {
  //       const { lock, unlockTime, lockedAmount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw())
  //         .to.emit(lock, "Withdrawal")
  //         .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
  //     });
  //   });

  //   describe("Transfers", function () {
  //     it("Should transfer the funds to the owner", async function () {
  //       const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).to.changeEtherBalances(
  //         [owner, lock],
  //         [lockedAmount, -lockedAmount]
  //       );
  //     });
  //   });
  // });
});

function expectWithinErrorBPS(actual: BN, expected: BN, tolerated_error_bps: number) {
  const difference = expected.gt(actual) ? expected.sub(actual) : actual.sub(expected);
  if (difference.eq(0)) {return;}
  const error_percentile_inverse = expected.div(difference);

  if (!error_percentile_inverse.gte(10000 / tolerated_error_bps)) {
    console.error(`expectWithinErrorBPS error:\nactual - ${actual}\nexpected - ${expected}`);
  }

  expect(error_percentile_inverse).gte(10000 / tolerated_error_bps);
}
