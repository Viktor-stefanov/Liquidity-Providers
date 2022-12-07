// SPDX-License-Identifier: No-License
pragma solidity 0.8.17;

import "../interfaces/IDiamondCut.sol";
import "../interfaces/IDiamond.sol";

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamonds.standart.diamond.storage");

    struct Facet {
        address facetAddress;
        uint16 selectorPosition;
    }

    struct DiamondStorage {
        address contractOwner;
        mapping(bytes4 => Facet) facet;
        bytes4[] selectors;
        mapping(bytes4 => uint256) selectorToIndex;
    }

    event OwnershipTransferred(
        address indexed prevOwner,
        address indexed newOwner
    );

    event DiamondCut(
        IDiamondCut.FacetCut[] _diamondCut,
        address _init,
        bytes _callData
    );

    function diamondStorage()
        internal
        pure
        returns (DiamondStorage storage ds)
    {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address prevOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(prevOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        if (msg.sender != diamondStorage().contractOwner) revert();
    }

    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (
            uint256 facetIndex;
            facetIndex < _diamondCut.length;
            facetIndex++
        ) {
            bytes4[] memory functionSelectors = _diamondCut[facetIndex]
                .functionSelectors;
            address facetAddress = _diamondCut[facetIndex].facetAddress;
            if (functionSelectors.length == 0) revert();

            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamond.FacetCutAction.Add)
                addFunctions(facetAddress, functionSelectors);
            else if (action == IDiamond.FacetCutAction.Replace)
                replaceFunctions(facetAddress, functionSelectors);
            else if (action == IDiamond.FacetCutAction.Remove)
                removeFunctions(facetAddress, functionSelectors);
            else revert();
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        if (_facetAddress == address(0)) revert();
        enforceHasContractCode(
            _facetAddress,
            "LibDIamondCut: Add facet has no code."
        );
        DiamondStorage storage ds = diamondStorage();
        uint16 selectorCount = uint16(_functionSelectors.length);
        for (uint256 index = 0; index < _functionSelectors.length; index++) {
            bytes4 selector = _functionSelectors[index];
            address oldFacetAddress = ds.facet[selector].facetAddress;
            if (oldFacetAddress != address(0)) revert(); // prohibit adding already existing function
            ds.facet[selector] = Facet(_facetAddress, selectorCount);
            ds.selectors.push(selector);
            ds.selectorToIndex[selector] = ++selectorCount;
        }
    }

    function replaceFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_facetAddress != address(0), "");
        enforceHasContractCode(
            _facetAddress,
            "LibDiamondCut: Replace facet has no code."
        );
        DiamondStorage storage ds = diamondStorage();
        for (
            uint256 selectorIndex = 0;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.facet[selector].facetAddress;
            require(oldFacetAddress != address(this), "Function is immutable.");
            require(
                oldFacetAddress != _facetAddress,
                "Can't replace facet with same facet."
            );
            require(
                oldFacetAddress != address(0),
                "Cannot have address 0 facet."
            );
            ds.facet[selector].facetAddress = _facetAddress;
        }
    }

    function removeFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_facetAddress != address(0), "");
        enforceHasContractCode(
            _facetAddress,
            "LibDiamondCut: Replace facet has no code."
        );
        DiamondStorage storage ds = diamondStorage();
        uint256 selectorCount = uint16(_functionSelectors.length);
        for (
            uint256 selectorIndex = 0;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            Facet memory oldFacet = ds.facet[selector];
            require(oldFacet.facetAddress != address(0), "No facet to remove.");
            require(
                oldFacet.facetAddress == address(this),
                "Can't remove an immutable function."
            );
            /// @TODO: decypher the next 6 lines of code
            if (oldFacet.selectorPosition != --selectorCount) {
                bytes4 lastSelector = ds.selectors[selectorCount];
                ds.selectors[oldFacet.selectorPosition] = lastSelector;
                ds.facet[lastSelector].selectorPosition = oldFacet
                    .selectorPosition;
            }
            ds.selectors.pop();
            delete ds.facet[selector];
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata)
        internal
    {
        // check if _init exists and has code and delegate the calldata
        if (_init == address(0)) return;
        enforceHasContractCode(
            _init,
            "LibDIamondCut: _init address has no code"
        );
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else revert();
        }
    }

    function enforceHasContractCode(
        address _contract,
        string memory _errorMessage
    ) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize != 0, _errorMessage);
    }
}
