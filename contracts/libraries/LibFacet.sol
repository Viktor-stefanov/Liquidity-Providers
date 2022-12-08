// SPDX-License-Identifier: No-License
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../PriceFeed.sol";
import "hardhat/console.sol";

library LibFacet {
    bytes32 constant FACET_STORAGE_POSITION =
        keccak256("diamond.standart.facet.storage");

    struct LiquidityShare {
        uint256 t1Amount;
        uint256 t2Amount;
    }

    struct PairPool {
        string token1;
        string token2;
        address token1Con;
        address token2Con;
        uint256 token1Amount;
        uint256 token2Amount;
        uint256 token1Seed;
        uint256 token2Seed;
        uint256 t1Fees;
        uint256 t2Fees;
        bool created;
    }

    struct FacetStorage {
        PriceFeed priceFeed;
        mapping(string => PairPool) tokenPools;
        mapping(string => mapping(address => LiquidityShare)) liquidityShares;
        mapping(string => address[]) liquidityProviders;
        string[] pools;
        uint256 feeDivisor;
        uint256 precisionMult;
        LiquidityShare share;
        PairPool pool;
    }

    function facetStorage() internal pure returns (FacetStorage storage fs) {
        bytes32 position = FACET_STORAGE_POSITION;
        assembly {
            fs.slot := position
        }
    }

    function poolIsSeeded(string memory _pair) internal view returns (bool) {
        FacetStorage storage fs = facetStorage();
        return
            fs.tokenPools[_pair].token1Seed != 0 &&
            fs.tokenPools[_pair].token2Seed != 0;
    }

    function abs(int256 _x) internal pure returns (uint256) {
        return _x >= 0 ? uint256(_x) : uint256(-_x);
    }

    function getLpShare(string memory _pair, address _user)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 t1Total;
        uint256 t2Total;
        (t1Total, t2Total) = getPoolDeposits(_pair);
        uint256 t1Stake = (facetStorage().precisionMult *
            facetStorage().liquidityShares[_pair][_user].t1Amount) / t1Total;
        uint256 t2Stake = (facetStorage().precisionMult *
            facetStorage().liquidityShares[_pair][_user].t2Amount) / t2Total;

        return (t1Stake, t2Stake);
    }

    function getPoolDeposits(string memory _pair)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 t1Total = 0;
        uint256 t2Total = 0;
        for (
            uint128 i = 0;
            i < facetStorage().liquidityProviders[_pair].length;
            i++
        ) {
            address lp = facetStorage().liquidityProviders[_pair][i];
            t1Total += LibFacet
            .facetStorage()
            .liquidityShares[_pair][lp].t1Amount;
            t2Total += LibFacet
            .facetStorage()
            .liquidityShares[_pair][lp].t2Amount;
        }

        return (t1Total, t2Total);
    }

    function getNoFeeWithdrawAmounts(
        string memory _pair,
        address _user,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) internal view returns (uint256, uint256) {
        uint256 t2Price = (facetStorage().precisionMult *
            facetStorage().tokenPools[_pair].token2Seed) /
            facetStorage().tokenPools[_pair].token1Seed;
        uint256 t1Price = (facetStorage().precisionMult *
            facetStorage().tokenPools[_pair].token1Seed) /
            facetStorage().tokenPools[_pair].token2Seed;

        uint256 t1Amount;
        uint256 t2Amount;
        (t1Amount, t2Amount) = _t1ToT2
            ? (
                _tokenAmount,
                (_tokenAmount * t2Price) / facetStorage().precisionMult
            )
            : (
                (_tokenAmount * t1Price) / facetStorage().precisionMult,
                _tokenAmount
            );

        if (facetStorage().tokenPools[_pair].token1Amount < t1Amount) {
            uint256 tokenDiff = abs(
                int256(facetStorage().tokenPools[_pair].token1Amount) -
                    int256(t1Amount)
            );
            t1Amount = facetStorage().tokenPools[_pair].token1Amount;
            uint256 ratio = _t1ToT2
                ? (facetStorage().precisionMult * _tokenAmount) /
                    LibFacet
                    .facetStorage()
                    .liquidityShares[_pair][_user].t1Amount
                : (facetStorage().precisionMult * _tokenAmount) /
                    LibFacet
                    .facetStorage()
                    .liquidityShares[_pair][_user].t2Amount;

            uint256 share = (ratio *
                LibFacet
                .facetStorage()
                .liquidityShares[_pair][_user].t2Amount) /
                facetStorage().precisionMult;
            t2Amount =
                share +
                ((tokenDiff * t2Price) / facetStorage().precisionMult);
        }

        if (facetStorage().tokenPools[_pair].token2Amount < t2Amount) {
            uint256 tokenDiff = abs(
                int256(facetStorage().tokenPools[_pair].token2Amount) -
                    int256(t2Amount)
            );
            t2Amount = facetStorage().tokenPools[_pair].token2Amount;
            uint256 ratio = _t1ToT2
                ? (facetStorage().precisionMult * _tokenAmount) /
                    LibFacet
                    .facetStorage()
                    .liquidityShares[_pair][_user].t1Amount
                : (facetStorage().precisionMult * _tokenAmount) /
                    LibFacet
                    .facetStorage()
                    .liquidityShares[_pair][_user].t2Amount;

            uint256 share = (ratio *
                LibFacet
                .facetStorage()
                .liquidityShares[_pair][_user].t1Amount) /
                facetStorage().precisionMult;
            t1Amount =
                share +
                ((tokenDiff * t1Price) / facetStorage().precisionMult);
        }

        return (t1Amount, t2Amount);
    }

    function getFeeBonus(string memory _pair, address _user)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 t1Stake;
        uint256 t2Stake;
        (t1Stake, t2Stake) = getLpShare(_pair, _user);

        return (
            (facetStorage().tokenPools[_pair].t1Fees * t1Stake) /
                facetStorage().precisionMult,
            (facetStorage().tokenPools[_pair].t2Fees * t2Stake) /
                facetStorage().precisionMult
        );
    }

    function sendWithdrawalAmounts(
        string memory _pair,
        bool _ethInPair,
        address _to,
        uint256 _t1Amount,
        uint256 _t2Amount,
        uint256 _t1Bonus,
        uint256 _t2Bonus
    ) internal {
        if (_ethInPair) {
            (bool success, ) = msg.sender.call{value: _t1Amount + _t1Bonus}("");
            require(success, "Error refunding ether.");
        } else {
            ERC20(facetStorage().tokenPools[_pair].token1Con).transfer(
                _to,
                _t1Amount + _t1Bonus
            );
        }
        ERC20(facetStorage().tokenPools[_pair].token2Con).transfer(
            _to,
            _t2Amount + _t2Bonus
        );
    }

    function withdrawShare(
        string memory _pair,
        address _to,
        uint256 _amount,
        bool _t1ToT2,
        bool _ethInPair
    ) internal {
        uint256 ratio = _t1ToT2
            ? (facetStorage().precisionMult * _amount) /
                facetStorage().liquidityShares[_pair][_to].t1Amount
            : (facetStorage().precisionMult * _amount) /
                facetStorage().liquidityShares[_pair][_to].t2Amount;
        (uint256 initT1Amount, uint256 initT2Amount) = _t1ToT2
            ? (
                _amount,
                (ratio *
                    LibFacet
                    .facetStorage()
                    .liquidityShares[_pair][_to].t2Amount) /
                    facetStorage().precisionMult
            )
            : (
                (ratio *
                    LibFacet
                    .facetStorage()
                    .liquidityShares[_pair][_to].t1Amount) /
                    facetStorage().precisionMult,
                _amount
            );

        (uint256 t1Amount, uint256 t2Amount) = getNoFeeWithdrawAmounts(
            _pair,
            _to,
            _amount,
            true
        );

        (uint256 t1Bonus, uint256 t2Bonus) = getFeeBonus(_pair, _to);
        facetStorage().tokenPools[_pair].t1Fees -= t1Bonus;
        facetStorage().tokenPools[_pair].t2Fees -= t2Bonus;

        LibFacet
        .facetStorage()
        .liquidityShares[_pair][_to].t1Amount -= initT1Amount;
        LibFacet
        .facetStorage()
        .liquidityShares[_pair][_to].t2Amount -= initT2Amount;

        console.log(facetStorage().tokenPools[_pair].token1Amount);
        console.log(t1Amount);
        console.log(facetStorage().tokenPools[_pair].token2Amount);
        console.log(t2Amount);
        facetStorage().tokenPools[_pair].token1Amount -= t1Amount;
        facetStorage().tokenPools[_pair].token2Amount -= t2Amount;

        LibFacet.sendWithdrawalAmounts(
            _pair,
            _ethInPair,
            _to,
            t1Amount,
            t2Amount,
            t1Bonus,
            t2Bonus
        );
    }

    function estimateDeposit(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) internal view returns (uint256[2] memory) {
        LibFacet.PairPool memory pool = LibFacet.facetStorage().tokenPools[
            _pair
        ];
        if (!LibFacet.poolIsSeeded(_pair))
            return
                _t1ToT2
                    ? [
                        _tokenAmount,
                        (((LibFacet.facetStorage().precisionMult *
                            LibFacet.facetStorage().priceFeed.getPrice(
                                pool.token1Con
                            )) /
                            LibFacet.facetStorage().priceFeed.getPrice(
                                pool.token2Con
                            )) * _tokenAmount) /
                            LibFacet.facetStorage().precisionMult
                    ]
                    : [
                        (((LibFacet.facetStorage().precisionMult *
                            LibFacet.facetStorage().priceFeed.getPrice(
                                pool.token2Con
                            )) /
                            LibFacet.facetStorage().priceFeed.getPrice(
                                pool.token1Con
                            )) * _tokenAmount) /
                            LibFacet.facetStorage().precisionMult,
                        _tokenAmount
                    ];

        if (_t1ToT2) {
            uint256 initPrice = (LibFacet.facetStorage().precisionMult *
                pool.token2Seed) / pool.token1Seed;
            uint256 tokenIn = ((((pool.token1Amount + _tokenAmount) *
                initPrice) / facetStorage().precisionMult) - pool.token2Amount);
            return [_tokenAmount, tokenIn];
        } else {
            uint256 initPrice = (LibFacet.facetStorage().precisionMult *
                pool.token1Seed) / pool.token2Seed;
            uint256 tokenIn = ((((pool.token2Amount + _tokenAmount) *
                initPrice) / LibFacet.facetStorage().precisionMult) -
                pool.token1Amount);
            return [tokenIn, _tokenAmount];
        }
    }

    function getRelativePrice(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) internal view returns (uint256) {
        LibFacet.PairPool memory pool = LibFacet.facetStorage().tokenPools[
            _pair
        ];
        uint256 fee = _tokenAmount / LibFacet.facetStorage().feeDivisor;
        uint256 invariant = pool.token1Amount * pool.token2Amount;

        return
            _t1ToT2
                ? pool.token2Amount -
                    (invariant / (pool.token1Amount + _tokenAmount - fee))
                : pool.token1Amount -
                    (invariant / (pool.token2Amount + _tokenAmount - fee));
    }

    function estimateWithdrawAmounts(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) internal view returns (uint256, uint256) {
        uint256 t1Amount;
        uint256 t2Amount;
        (t1Amount, t2Amount) = getNoFeeWithdrawAmounts(
            _pair,
            msg.sender,
            _tokenAmount,
            _t1ToT2
        );
        uint256 t1Bonus;
        uint256 t2Bonus;
        (t1Bonus, t2Bonus) = getFeeBonus(_pair, msg.sender);

        return (t1Amount + t1Bonus, t2Amount + t2Bonus);
    }
}

contract Modifiers {
    modifier poolCreated(string memory _pair) {
        require(
            LibFacet.facetStorage().tokenPools[_pair].created,
            "There is no such token contract YET deployed in our system."
        );
        _;
    }

    modifier hasTokens(
        string memory _pair,
        uint256 _contractNumber,
        uint256 _tokenAmount
    ) {
        address contractAddress = _contractNumber == 1
            ? LibFacet.facetStorage().tokenPools[_pair].token1Con
            : LibFacet.facetStorage().tokenPools[_pair].token2Con;
        require(
            ERC20(contractAddress).balanceOf(msg.sender) >= _tokenAmount,
            "Insufficient ERC20 funds."
        );
        _;
    }

    modifier isShareHolder(string memory _pair) {
        require(
            LibFacet
            .facetStorage()
            .liquidityShares[_pair][msg.sender].t1Amount >
                0 &&
                LibFacet
                .facetStorage()
                .liquidityShares[_pair][msg.sender].t2Amount >
                0,
            "Only shareholders of the liquidity pool can call this function."
        );
        _;
    }

    modifier hasShares(
        string memory _pair,
        uint256 _share,
        bool _t1ToT2
    ) {
        require(
            _t1ToT2
                ? LibFacet
                .facetStorage()
                .liquidityShares[_pair][msg.sender].t1Amount >= _share
                : LibFacet
                .facetStorage()
                .liquidityShares[_pair][msg.sender].t2Amount >= _share,
            "Cannot withdraw more than has been deposited."
        );
        _;
    }
}
