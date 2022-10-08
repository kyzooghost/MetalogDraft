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
  const TEN: BN = BN.from('10').pow(18).mul(10);
  const e: BN = BN.from('2718281828459045235');
  const SCALE_FACTOR = ONE;

  enum MetalogBoundChoice {
    UNBOUNDED,
    BOUNDED_BELOW,
    BOUNDED_ABOVE,
    BOUNDED,
  }

  interface MetalogBoundParameters {
    boundChoice: MetalogBoundChoice;
    lowerBound: BN;
    upperBound: BN;
  }

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
      expectWithinErrorBPS(await test.ln(EIGHT), BN.from('2079441541679835928'), 1);
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

  describe('Nine-term unbounded metalog getQuantile', function () {
    const COEFFICIENTS: BN[] = [
      BN.from('996043875471054000'),
      BN.from('051024209692504000'),
      BN.from('040340911286869100').mul(-1),
      BN.from('181985469221972000').mul(-1),
      BN.from('089194887103685600'),
      BN.from('162518488572285000').mul(-1),
      BN.from('516451225277333000'),
      BN.from('118180213813597000'),
      BN.from('261748715887528000').mul(-1),
    ];

    const boundParameters: MetalogBoundParameters = {
      boundChoice: MetalogBoundChoice.UNBOUNDED,
      lowerBound: ZERO,
      upperBound: ZERO,
    };

    it('should revert for p < 0%', async function () {
      const PERCENTILE = ZERO.sub(1);
      await expect(metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters)).to.be.revertedWith(
        'percentile_ <= 0%'
      );
    });

    it('should revert for p = 0%', async function () {
      const PERCENTILE = ZERO;
      await expect(metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters)).to.be.revertedWith(
        'percentile_ <= 0%'
      );
    });

    it('should revert for p = 100%', async function () {
      const PERCENTILE = ONE;
      await expect(metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters)).to.be.revertedWith(
        'percentile_ >= 100%'
      );
    });

    it('should revert for p > 100%', async function () {
      const PERCENTILE = ONE.add(1);
      await expect(metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters)).to.be.revertedWith(
        'percentile_ >= 100%'
      );
    });

    it('p = 0.001', async function () {
      const PERCENTILE = ONE.div(1000);
      expectWithinErrorBPS(
        await metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters),
        BN.from('918136864905447000'),
        1
      );
    });

    it('p = 0.01', async function () {
      const PERCENTILE = ONE.div(100);
      expectWithinErrorBPS(
        await metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters),
        BN.from('948683175129611000'),
        1
      );
    });

    it('p = 0.1', async function () {
      const PERCENTILE = ONE.div(10);
      expectWithinErrorBPS(
        await metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters),
        BN.from('969541856156500000'),
        1
      );
    });

    it('p = 0.25', async function () {
      const PERCENTILE = ONE.div(4);
      expectWithinErrorBPS(
        await metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters),
        BN.from('984075048361894000'),
        1
      );
    });

    it('p = 0.5', async function () {
      const PERCENTILE = HALF;
      expectWithinErrorBPS(
        await metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters),
        BN.from('996043875467933000'),
        1
      );
    });

    it('p = 0.75', async function () {
      const PERCENTILE = ONE.mul(3).div(4);
      expectWithinErrorBPS(
        await metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters),
        BN.from('999014961031336000'),
        1
      );
    });

    it('p = 0.9', async function () {
      const PERCENTILE = ONE.mul(9).div(10);
      expectWithinErrorBPS(
        await metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters),
        BN.from('1000013855209570000'),
        1
      );
    });

    it('p = 0.99', async function () {
      const PERCENTILE = ONE.mul(99).div(100);
      expectWithinErrorBPS(
        await metaLog.getQuantile(PERCENTILE, COEFFICIENTS, boundParameters),
        BN.from('1002172587132820000'),
        1
      );
    });
  });

  describe('Nine-term unbounded metalog getApproximatePercentile', function () {
    const COEFFICIENTS: BN[] = [
      BN.from('996043875471054000'),
      BN.from('051024209692504000'),
      BN.from('040340911286869100').mul(-1),
      BN.from('181985469221972000').mul(-1),
      BN.from('089194887103685600'),
      BN.from('162518488572285000').mul(-1),
      BN.from('516451225277333000'),
      BN.from('118180213813597000'),
      BN.from('261748715887528000').mul(-1),
    ];

    const boundParameters: MetalogBoundParameters = {
      boundChoice: MetalogBoundChoice.UNBOUNDED,
      lowerBound: ZERO,
      upperBound: ZERO,
    };

    it('p = 0.75', async function () {
      const QUANTILE = BN.from('948683175129611000');
      console.log(await metaLog.getApproximatePercentile(QUANTILE, COEFFICIENTS, boundParameters));
    });

    // it('p = 0.5', async function () {
    //   const QUANTILE = BN.from('996043875467933000');
    //   console.log(await metaLog.getApproximatePercentile(QUANTILE, COEFFICIENTS, boundParameters));
    // });
  });
});

function expectWithinErrorBPS(actual: BN, expected: BN, tolerated_error_bps: number) {
  const difference = expected.gt(actual) ? expected.sub(actual) : actual.sub(expected);
  if (difference.eq(0)) {
    return;
  }
  const error_percentile_inverse = expected.div(difference);

  if (!error_percentile_inverse.gte(10000 / tolerated_error_bps)) {
    console.error(`expectWithinErrorBPS error:\nactual - ${actual}\nexpected - ${expected}`);
  }

  expect(error_percentile_inverse).gte(10000 / tolerated_error_bps);
}
