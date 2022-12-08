// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PriceFeed.sol";
import "./libraries/LibFacet.sol";

contract ERC20ToERC20 is ERC20, Modifiers {
    constructor() ERC20("ERC20ToERC20", "ETET") {}

    function depositErcToErc(
        string memory _pair,
        uint256 _token1Amount,
        uint256 _token2Amount
    )
        external
        Modifiers.poolCreated(_pair)
        Modifiers.hasTokens(_pair, 1, _token1Amount)
        Modifiers.hasTokens(_pair, 2, _token2Amount)
    {
        uint256 t2Goal = estimateErcToErcDeposit(_pair, _token1Amount, true)[1];
        require(
            LibFacet.abs(int256(t2Goal) - int256(_token2Amount)) < 10**10,
            "Amount inserted is not helping the pool get to equilibrium state."
        );

        ERC20(LibFacet.facetStorage().tokenPools[_pair].token1Con).transferFrom(
                msg.sender,
                address(this),
               _token1Amount 
            );
        ERC20(LibFacet.facetStorage().tokenPools[_pair].token2Con).transferFrom(
                msg.sender,
                address(this),
               _token2Amount 
            );

        LibFacet.facetStorage().tokenPools[_pair].token1Amount += _token1Amount;
        LibFacet.facetStorage().tokenPools[_pair].token2Amount += _token2Amount;

        if (
            LibFacet
            .facetStorage()
            .liquidityShares[_pair][msg.sender].t1Amount ==
            0 &&
            LibFacet
            .facetStorage()
            .liquidityShares[_pair][msg.sender].t2Amount ==
            0
        ) LibFacet.facetStorage().liquidityProviders[_pair].push(msg.sender);
        LibFacet
        .facetStorage()
        .liquidityShares[_pair][msg.sender].t1Amount += _token1Amount;
        LibFacet
        .facetStorage()
        .liquidityShares[_pair][msg.sender].t2Amount += _token2Amount;

        if (LibFacet.facetStorage().tokenPools[_pair].token1Seed == 0) {
            LibFacet.facetStorage().tokenPools[_pair].token1Seed = _token1Amount;
            LibFacet.facetStorage().tokenPools[_pair].token2Seed = _token2Amount;
        }
    }

    function ercToErcSwap(
        string memory _pair,
        uint256 _tokenAmount,
        bool _t1ToT2
    ) external {
        require(
            _t1ToT2
                ? ERC20(LibFacet.facetStorage().tokenPools[_pair].token1Con)
                    .balanceOf(msg.sender) >= _tokenAmount
                : ERC20(LibFacet.facetStorage().tokenPools[_pair].token2Con)
                    .balanceOf(msg.sender) >= _tokenAmount,
            "Insufficient ERC20 balance."
        );

        LibFacet.PairPool memory pool = LibFacet.facetStorage().tokenPools[
            _pair
        ];
        uint256 fee = _tokenAmount / 500;
        uint256 invariant = pool.token1Amount * pool.token2Amount;
        uint256 newToken1Pool;
        uint256 newToken2Pool;
        uint256 tokensOut;
        if (_t1ToT2) {
            newToken1Pool = pool.token1Amount + _tokenAmount;
            newToken2Pool = invariant / (newToken1Pool - fee);
            tokensOut = pool.token2Amount - newToken2Pool;
        } else {
            newToken2Pool = pool.token2Amount + _tokenAmount;
            newToken1Pool = invariant / (newToken2Pool - fee);
            tokensOut = pool.token1Amount - newToken1Pool;
        }
        pool.token1Amount = newToken1Pool;
        pool.token2Amount = newToken2Pool;
        LibFacet.facetStorage().tokenPools[_pair] = pool;

        ERC20 fromContract = _t1ToT2
            ? ERC20(pool.token1Con)
            : ERC20(pool.token2Con);
        ERC20 toContract = _t1ToT2
            ? ERC20(pool.token2Con)
            : ERC20(pool.token1Con);

        fromContract.transferFrom(msg.sender, address(this), _tokenAmount);
        toContract.transfer(msg.sender, tokensOut);

        LibFacet.facetStorage().tokenPools[_pair].t1Fees += fee;
        LibFacet.facetStorage().tokenPools[_pair].token1Amount = newToken1Pool;
        LibFacet.facetStorage().tokenPools[_pair].token2Amount = newToken2Pool;
    }

    function estimateErcToErcWithdrawAmounts(string memory _pair, uint256 _amount, bool _t1ToT2) external view returns (uint256, uint256) {
        return LibFacet.estimateWithdrawAmounts(_pair, _amount, _t1ToT2);
    }

    function ercToErcWithdraw(
        string memory _pair,
        uint256 _amount,
        bool _t1ToT2

   ) external {
        LibFacet.withdrawShare(_pair, msg.sender, _amount, _t1ToT2, false);
    }

    function getPoolDeposits(string memory _pair) external view returns (uint256, uint256){
        return LibFacet.getPoolDeposits(_pair);
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

    function poolExists(string memory _pair) external view returns (bool) {
        return LibFacet.facetStorage().tokenPools[_pair].created;
    }

    function estimateErcToErcDeposit(string memory _pair, uint256 _tokenAmount, bool _t1ToT2) public view returns (uint256[2] memory) {
        return LibFacet.estimateDeposit(_pair, _tokenAmount, _t1ToT2);
    }

    function getRelativePrice(string memory _pair, uint256 _tokenAmount, bool _t1ToT2) external view returns (uint256) {
        return LibFacet.getRelativePrice(_pair, _tokenAmount, _t1ToT2);
    }

}
