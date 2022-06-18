// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
//import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./DvlpControlRole.sol";

contract DvlpCollection is
    IERC2981,
    Ownable,
    ERC165Storage,
    IERC1155MetadataURI,
    ERC1155,
    DvlpControlRole
{
    using Strings for uint256;
    using SafeMath for uint256;
    //using Counters for Counters.Counter;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    string public name;
    string public symbol;

    /// @dev royalty percent of 2nd sale. ex: 1 = 1%.
    uint256 public royaltyPercent;

    // id => creator
    mapping(uint256 => address) public creators;

    // id => revealed flag
    mapping(uint256 => bool) public revealedNfts;

    //Token URI prefix
    string public tokenURIPrefix;
    bool private revealedFl;

    /**
     * @dev Constructor Function
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory _tokenURIPrefix,
        uint256 royaltyPercent_
    ) ERC1155(_tokenURIPrefix) {
        name = name_;
        symbol = symbol_;
        tokenURIPrefix = _tokenURIPrefix;
        royaltyPercent = royaltyPercent_;
        revealedFl = false;
        addAdmin(_msgSender());
        addMinter(_msgSender());
        _registerInterface(_INTERFACE_ID_ERC2981);
    }

    /**
     * @dev Internal function to set the token URI prefix.
     * @param _tokenURIPrefix string URI prefix to assign
     */
    function _setTokenURIPrefix(string memory _tokenURIPrefix) internal {
        tokenURIPrefix = _tokenURIPrefix;
    }

    // Creates a new token type and assings _initialSupply to minter
    function safeMint(
        address _beneficiary,
        uint256 _id,
        uint256 _supply,
        bool _revealedFl
    ) internal {
        require(creators[_id] == address(0x0), "Token is already minted");
        require(_supply != 0, "Supply should be positive");

        creators[_id] = msg.sender;
        revealedNfts[_id] = _revealedFl;
        _mint(_beneficiary, _id, _supply, "");
    }

    // Creates a new tokens type and assings _initialSupplys to minter
    function safeMintBatch(
        address _beneficiary,
        uint256[] memory _ids,
        uint256[] memory _supplys,
        bool[] memory _revealedFls
    ) internal {
        for (uint256 i = 0; i < _ids.length; i++) {
            require(
                creators[_ids[i]] == address(0x0),
                "Token is already minted"
            );
            require(_supplys[i] != 0, "Supply should be positive");

            creators[_ids[i]] = msg.sender;
            revealedNfts[_ids[i]] = _revealedFls[i];
        }
        _mintBatch(_beneficiary, _ids, _supplys, "");
    }

    function burn(
        address _owner,
        uint256 _id,
        uint256 _value
    ) external {
        require(
            _owner == msg.sender ||
                isApprovedForAll(_owner, msg.sender) == true,
            "Need operator approval for 3rd party burns."
        );
        _burn(_owner, _id, _value);
    }

    function uri(uint256 _id)
        public
        view
        virtual
        override(ERC1155, IERC1155MetadataURI)
        returns (string memory)
    {
        require(creators[_id] != address(0x0), "Token not minted");
        if (revealedNfts[_id] == true) {
            return
                bytes(tokenURIPrefix).length > 0
                    ? string(
                        abi.encodePacked(
                            tokenURIPrefix,
                            _id.toString(),
                            ".json"
                        )
                    )
                    : "";
        } else if (revealedNfts[_id] == false) {
            return
                bytes(tokenURIPrefix).length > 0
                    ? string(abi.encodePacked(tokenURIPrefix, "hiddenNFT.json"))
                    : "";
        } else {
            return "";
        }
    }

    /*     function _setNewURI(string memory newuri) external onlyOwner {
        _setTokenURIPrefix(newuri);
         _setURI(newuri);
    } */

    function contractURI() public view returns (string memory) {
        return
            bytes(tokenURIPrefix).length > 0
                ? string(
                    abi.encodePacked(
                        tokenURIPrefix,
                        "dvlp_contract_metadata.json"
                    )
                )
                : "";
    }

    function revealSwitch(uint256 _id) public onlyMinter {
        require(creators[_id] != address(0x0), "Token not minted");
        if (revealedNfts[_id] == true) {
            revealedNfts[_id] = false;
        } else if (revealedNfts[_id] == false) {
            revealedNfts[_id] = true;
        }
    }

    function revealSwitchBatch(uint256[] memory _ids) public onlyMinter {
        for (uint256 i = 0; i < _ids.length; i++) {
            require(creators[_ids[i]] != address(0x0), "Token not minted");
            if (revealedNfts[_ids[i]] == true) {
                revealedNfts[_ids[i]] = false;
            } else if (revealedNfts[_ids[i]] == false) {
                revealedNfts[_ids[i]] = true;
            }
        }
    }

    function mint(
        address _beneficiary,
        uint256 _id,
        uint256 _supply,
        bool _revealedFl
    ) public onlyMinter returns (uint256) {
        revealedFl = _revealedFl;
        safeMint(_beneficiary, _id, _supply, _revealedFl);
        return _id;
    }

    function mintBatch(
        address _beneficiary,
        uint256[] memory _supply,
        uint256[] memory _tid,
        bool[] memory _revealedFls
    ) public onlyMinter {
        safeMintBatch(_beneficiary, _tid, _supply, _revealedFls);
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override(IERC2981)
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = creators[tokenId];
        royaltyAmount = salePrice.mul(royaltyPercent).div(100);
    }

    function setRoyalty(uint256 _royalty) public onlyAdmin {
        royaltyPercent = _royalty;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC165Storage, ERC1155, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            interfaceId == type(IAccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
