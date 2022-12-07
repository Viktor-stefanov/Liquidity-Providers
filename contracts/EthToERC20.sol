// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libraries/LibFacet.sol";
import "hardhat/console.sol";

contract EthToERC20 is ERC20 {
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
            LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t1Amount > 0 &&
                LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t2Amount > 0,
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
                ? LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t1Amount >= _share
                : LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t2Amount >= _share,
            "Unable to withdraw more than has been deposited."
        );
        _;
    }

    constructor() ERC20("EthToErc", "E2E") {}

    function deposit(string memory _pair, uint256 _tokenAmount)
        external
        payable
        poolCreated(_pair)
        hasTokens(_pair, 2, _tokenAmount)
    {
        
        uint256 tokenGoal = estimateDeposit(_pair, msg.value, true)[1];
        require(
            abs(int256(tokenGoal) - int256(_tokenAmount)) < 10**10,
            "Amount inserted is not helping the pool get to equilibrium state."
        );

        ERC20(LibFacet.facetStorage().tokenPools[_pair].token2Con).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        LibFacet.facetStorage().tokenPools[_pair].token1Amount += msg.value;
        LibFacet.facetStorage().tokenPools[_pair].token2Amount += _tokenAmount;

        if (
            LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t1Amount == 0 &&
            LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t2Amount == 0
        ) LibFacet.facetStorage().liquidityProviders[_pair].push(msg.sender);
        LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t1Amount += msg.value;
        LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t2Amount += _tokenAmount;

        if (LibFacet.facetStorage().tokenPools[_pair].token1Seed == 0) {
            LibFacet.facetStorage().tokenPools[_pair].token1Seed = msg.value;
            LibFacet.facetStorage().tokenPools[_pair].token2Seed = _tokenAmount;
        }
    }

    function ethToERC20Swap(string memory _pair)
        external
        payable
        poolCreated(_pair)
    {
        
        LibFacet.PairPool memory pool = LibFacet.facetStorage().tokenPools[_pair];
        uint256 fee = msg.value / LibFacet.facetStorage().feeDivisor;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newEthAmount = pool.token1Amount + msg.value;
        uint256 newTokenAmount = invariant / (newEthAmount - fee);
        uint256 tokensOut = pool.token2Amount - newTokenAmount;

        LibFacet.facetStorage().tokenPools[_pair].t1Fees += fee;
        LibFacet.facetStorage().tokenPools[_pair].token1Amount = newEthAmount;
        LibFacet.facetStorage().tokenPools[_pair].token2Amount = newTokenAmount;

        ERC20(pool.token2Con).transfer(msg.sender, tokensOut);
    }

    function ERC20ToEthSwap(
        string memory _pair,
        address _tokenContract,
        uint256 _tokenAmount
    ) external poolCreated(_pair) hasTokens(_pair, 1, _tokenAmount) {
        
        LibFacet.PairPool memory pool = LibFacet.facetStorage().tokenPools[_pair];
        uint256 fee = _tokenAmount / LibFacet.facetStorage().feeDivisor;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newTokenPool = pool.token2Amount + _tokenAmount;
        uint256 newEthPool = invariant / (newTokenPool - fee);
        uint256 ethOut = pool.token1Amount - newEthPool;

        LibFacet.facetStorage().tokenPools[_pair].t2Fees += fee;
        LibFacet.facetStorage().tokenPools[_pair].token1Amount = newEthPool;
        LibFacet.facetStorage().tokenPools[_pair].token2Amount = newTokenPool;

        ERC20(_tokenContract).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        (bool success, ) = msg.sender.call{value: ethOut}("");
        require(success, "Could not send eth.");
    }

    function withdrawShare(
        string memory _pair,
        uint256 _amount,
        bool _t1ToT2
    ) external isShareHolder(_pair) hasShares(_pair, _amount, _t1ToT2) {
        
        uint256 ratio = _t1ToT2
            ? (LibFacet.facetStorage().precisionMult * _amount) /
                LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t1Amount
            : (LibFacet.facetStorage().precisionMult * _amount) /
                LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t2Amount;
        (uint256 initT1Amount, uint256 initT2Amount) = _t1ToT2
            ? (
                _amount,
                (ratio * LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t2Amount) /
                    LibFacet.facetStorage().precisionMult
            )
            : (
                (ratio * LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t1Amount) /
                    LibFacet.facetStorage().precisionMult,
                _amount
            );

        withdrawShare2(_pair, _amount, initT1Amount, initT2Amount);
    }

    function withdrawShare2(
        string memory _pair,
        uint256 _amount,
        uint256 initT1Amount,
        uint256 initT2Amount
    ) internal {
        
        (uint256 t1Amount, uint256 t2Amount) = getNoFeeWithdrawAmounts(
            _pair,
            msg.sender,
            _amount,
            true
        );

        (uint256 t1Bonus, uint256 t2Bonus) = getFeeBonus(_pair, msg.sender);
        LibFacet.facetStorage().tokenPools[_pair].t1Fees -= t1Bonus;
        LibFacet.facetStorage().tokenPools[_pair].t2Fees -= t2Bonus;

        LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t1Amount -= initT1Amount;
        LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t2Amount -= initT2Amount;
        LibFacet.facetStorage().tokenPools[_pair].token1Amount -= t1Amount;
        LibFacet.facetStorage().tokenPools[_pair].token2Amount -= t2Amount;

        ERC20(LibFacet.facetStorage().tokenPools[_pair].token2Con).transfer(
            msg.sender,
            t2Amount + t2Bonus
        );
        (bool success, ) = msg.sender.call{value: t1Amount + t1Bonus}("");
        require(success, "Error refunding ether.");
    }

    function estimateDeposit(
        string memory _pair,
        uint256 _tokenAmount,
        bool ethToERC20
    ) public view returns (uint256[2] memory) {
        
        LibFacet.PairPool memory pool = LibFacet.facetStorage().tokenPools[_pair];
        if (!poolIsSeeded(_pair))
            return
                ethToERC20
                    ? [
                        _tokenAmount,
                        (((LibFacet.facetStorage().precisionMult *
                            LibFacet.facetStorage().priceFeed.getPrice(pool.token1Con)) /
                            LibFacet.facetStorage().priceFeed.getPrice(pool.token2Con)) *
                            _tokenAmount) / LibFacet.facetStorage().precisionMult
                    ]
                    : [
                        (((LibFacet.facetStorage().precisionMult *
                            LibFacet.facetStorage().priceFeed.getPrice(pool.token2Con)) /
                            LibFacet.facetStorage().priceFeed.getPrice(pool.token1Con)) *
                            _tokenAmount) / LibFacet.facetStorage().precisionMult,
                        _tokenAmount
                    ];

        if (ethToERC20) {
            uint256 initPrice = (LibFacet.facetStorage().precisionMult * pool.token2Seed) /
                pool.token1Seed;
            uint256 tokenIn = (((pool.token1Amount + _tokenAmount) *
                initPrice) - (pool.token2Amount * LibFacet.facetStorage().precisionMult)) /
                LibFacet.facetStorage().precisionMult;
            return [_tokenAmount, tokenIn];
        } else {
            uint256 initPrice = (LibFacet.facetStorage().precisionMult * pool.token1Seed) /
                pool.token2Seed;
            uint256 tokenIn = (((pool.token2Amount + _tokenAmount) *
                initPrice) - (pool.token1Amount * LibFacet.facetStorage().precisionMult)) /
                LibFacet.facetStorage().precisionMult;
            return [tokenIn, _tokenAmount];
        }
    }

    function getNoFeeWithdrawAmounts(
        string memory _pair,
        address _user,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) internal view returns (uint256, uint256) {
        
        uint256 t2Price = (LibFacet.facetStorage().precisionMult * LibFacet.facetStorage().tokenPools[_pair].token2Seed) /
            LibFacet.facetStorage().tokenPools[_pair].token1Seed;
        uint256 t1Price = (LibFacet.facetStorage().precisionMult * LibFacet.facetStorage().tokenPools[_pair].token1Seed) /
            LibFacet.facetStorage().tokenPools[_pair].token2Seed;

        uint256 t1Amount;
        uint256 t2Amount;
        (t1Amount, t2Amount) = _t1ToT2
            ? (_tokenAmount, (_tokenAmount * t2Price) / LibFacet.facetStorage().precisionMult)
            : ((_tokenAmount * t1Price) / LibFacet.facetStorage().precisionMult, _tokenAmount);

        if (LibFacet.facetStorage().tokenPools[_pair].token1Amount < t1Amount) {
            uint256 tokenDiff = abs(
                int256(LibFacet.facetStorage().tokenPools[_pair].token1Amount) - int256(t1Amount)
            );
            t1Amount = LibFacet.facetStorage().tokenPools[_pair].token1Amount;
            uint256 ratio = _t1ToT2
                ? (LibFacet.facetStorage().precisionMult * _tokenAmount) /
                    LibFacet.facetStorage().liquidityShares[_pair][_user].t1Amount
                : (LibFacet.facetStorage().precisionMult * _tokenAmount) /
                    LibFacet.facetStorage().liquidityShares[_pair][_user].t2Amount;

            uint256 share = (ratio *
                LibFacet.facetStorage().liquidityShares[_pair][_user].t2Amount) / LibFacet.facetStorage().precisionMult;
            t2Amount = share + ((tokenDiff * t2Price) / LibFacet.facetStorage().precisionMult);
        }

        if (LibFacet.facetStorage().tokenPools[_pair].token2Amount < t2Amount) {
            uint256 tokenDiff = abs(
                int256(LibFacet.facetStorage().tokenPools[_pair].token2Amount) - int256(t2Amount)
            );
            t2Amount = LibFacet.facetStorage().tokenPools[_pair].token2Amount;
            uint256 ratio = _t1ToT2
                ? (LibFacet.facetStorage().precisionMult * _tokenAmount) /
                    LibFacet.facetStorage().liquidityShares[_pair][_user].t1Amount
                : (LibFacet.facetStorage().precisionMult * _tokenAmount) /
                    LibFacet.facetStorage().liquidityShares[_pair][_user].t2Amount;

            uint256 share = (ratio *
                LibFacet.facetStorage().liquidityShares[_pair][_user].t1Amount) / LibFacet.facetStorage().precisionMult;
            t1Amount = share + ((tokenDiff * t1Price) / LibFacet.facetStorage().precisionMult);
        }

        return (t1Amount, t2Amount);
    }

    function estimateWithdrawAmounts(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) external view returns (uint256, uint256) {
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

    function getRelativePrice(
        string memory _pair,
        uint256 _tokenAmount,
        bool ethToERC20
    ) external view poolCreated(_pair) returns (uint256) {
        
        LibFacet.PairPool memory pool = LibFacet.facetStorage().tokenPools[_pair];
        uint256 fee = _tokenAmount / LibFacet.facetStorage().feeDivisor;
        uint256 invariant = pool.token1Amount * pool.token2Amount;

        return
            ethToERC20
                ? pool.token2Amount -
                    (invariant / (pool.token1Amount + _tokenAmount - fee))
                : pool.token1Amount -
                    (invariant / (pool.token2Amount + _tokenAmount - fee));
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
            (LibFacet.facetStorage().tokenPools[_pair].t1Fees * t1Stake) / LibFacet.facetStorage().precisionMult,
            (LibFacet.facetStorage().tokenPools[_pair].t2Fees * t2Stake) / LibFacet.facetStorage().precisionMult
        );
    }

    function getLpShare(string memory _pair, address _user)
        public
        view
        returns (uint256, uint256)
    {
        
        uint256 t1Total;
        uint256 t2Total;
        (t1Total, t2Total) = getPoolDeposits(_pair);
        uint256 t1Stake = (LibFacet.facetStorage().precisionMult *
            LibFacet.facetStorage().liquidityShares[_pair][_user].t1Amount) / t1Total;
        uint256 t2Stake = (LibFacet.facetStorage().precisionMult *
            LibFacet.facetStorage().liquidityShares[_pair][_user].t2Amount) / t2Total;

        return (t1Stake, t2Stake);
    }

    function getPoolDeposits(string memory _pair)
        public
        view
        returns (uint256, uint256)
    {
        
        uint256 t1Total = 0;
        uint256 t2Total = 0;
        for (uint128 i = 0; i < LibFacet.facetStorage().liquidityProviders[_pair].length; i++) {
            address lp = LibFacet.facetStorage().liquidityProviders[_pair][i];
            t1Total += LibFacet.facetStorage().liquidityShares[_pair][lp].t1Amount;
            t2Total += LibFacet.facetStorage().liquidityShares[_pair][lp].t2Amount;
        }

        return (t1Total, t2Total);
    }

    function getUserDeposits(string memory _pair)
        external
        view
        returns (uint256, uint256)
    {
        
        return (
            LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t1Amount,
            LibFacet.facetStorage().liquidityShares[_pair][msg.sender].t2Amount
        );
    }

    function abs(int256 _x) internal pure returns (uint256) {
        return _x >= 0 ? uint256(_x) : uint256(-_x);
    }

    function getPools() external view returns (string[] memory) {
        
        return LibFacet.facetStorage().pools;
    }

    function getLiquidityProviders(string memory _pair)
        internal
        view
        returns (address[] memory)
    {
        
        return LibFacet.facetStorage().liquidityProviders[_pair];
    }

    function poolIsSeeded(string memory _pair) internal view returns (bool) {
        
        return LibFacet.facetStorage().tokenPools[_pair].token1Seed != 0;
    }

    receive() external payable {}
}
