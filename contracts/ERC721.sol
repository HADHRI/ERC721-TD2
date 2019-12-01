pragma solidity >=0.4.21 <0.6.0;
import "../utils/Counters.sol";
import "../utils/IERC721Receiver.sol";
import "../utils/Context.sol";
import "../utils/Adress.sol";
import "../utils/WhitelistedRole.sol";
contract ERC721 is Context,WhitelistedRole{
 using Counters for Counters.Counter;
 using Address for address;
 using SafeMath for uint256;

 // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
 // Mapping from token ID to owner
    mapping (uint256 => address) private _tokenOwner;

// Mapping from owner to number of owned token
    mapping (address => Counters.Counter) private _ownedTokensCount;

 // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;
// Mapping for auctionedAnimalsba
    mapping (uint => bool) private _auctionedAnimals;

    mapping (uint => Auction) private _auctions;


 // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
  event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
  event BreederAdded(address indexed breeder);
  event AnimalDeleted(address indexed owner, uint tokenId);
  event NewBorn(address indexed owner, uint tokenId);
  event AuctionCreated(address indexed seller, uint tokenId);
event AuctionClaimed(address indexed claimer, uint tokenId);
  event NewBid(address indexed bidder, uint tokenId, uint price);
  event AnimalTransfered(address indexed from, address indexed to, uint tokenId);

    enum AnimalType { Cow, Horse, Chicken, Pig, Sheep, Donkey, Rabbit, Duck }
    enum Age { Young, Adult, Old }
    enum Color { Brown, Black, White, Red, Blue }

    struct Animal {
        uint id;
        AnimalType race;
        Age age;
        Color color;
        uint rarity;
        bool isMale;
        bool canBreed;
        }
    struct Auction {
        address seller;
        address lastBidder;
        uint startDate;
        uint initialPrice;
        uint priceToBid;
        uint bestOffer;
    }
    
    //Animal ID
    uint private _currentId;
    mapping (address => Animal[]) private _animalsOfOwner;
    mapping (uint => Animal) private _animalsById;
    mapping (uint => address) private _animalToOwner;
     
    modifier onlyOwnerOfAnimal(uint id) {
        require(msg.sender == _animalToOwner[id], "Not animal owner");
        _;
    }
     modifier onlyAuctionedAnimal(uint id) {
        require(_auctionedAnimals[id], "not auctioned animal");
        _;
    }
 /**
     * @dev Gets the balance of the specified address.
     * @param owner address to query the balance of
     * @return uint256 representing the amount owned by the passed address
     */
    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _ownedTokensCount[owner].current();
    }

/**
     * @dev Gets the owner of the specified token ID.
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _tokenOwner[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    } 

     /**
     * @dev Transfers the ownership of a given token ID to another address.
     * Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     * Requires the msg.sender to be the owner, approved, or operator.
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transferFrom(from, to, tokenId);
    }
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

     function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransferFrom(from, to, tokenId, _data);
    }

     /**
     * @dev Approves another address to transfer the given token ID
     * The zero address indicates there is no approved address.
     * There can only be one approved address per token at a given time.
     * Can only be called by the token owner or an approved operator.
     * @param to address to be approved for the given token ID
     * @param tokenId uint256 ID of the token to be approved
     */
    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Gets the approved address for a token ID, or zero if no address set
     * Reverts if the token ID does not exist.
     * @param tokenId uint256 ID of the token to query the approval of
     * @return address currently approved for the given token ID
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

     /**
     * @dev Tells whether an operator is approved by a given owner.
     * @param owner owner address which you want to query the approval of
     * @param operator operator address which you want to query the approval of
     * @return bool whether the given operator is approved by the given owner
     */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Sets or unsets the approval of a given operator
     * An operator is allowed to transfer all tokens of the sender on their behalf.
     * @param to operator address to set the approval
     * @param approved representing the status of the approval to be set
     */
    function setApprovalForAll(address to, bool approved) public {
        require(to != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][to] = approved;
        emit ApprovalForAll(_msgSender(), to, approved);
    }
    //Adding a breeder to whiteList but only by a person in the whitelistAdmin
    function registerBreeder(address account) public onlyWhitelisted { 
        require(!isWhitelisted(account), "Breeder Already added");
        addWhitelisted(account);  
         emit BreederAdded(account);
    }

    //This function will declare an Animal for onlyBreeder (it means in the whiteList)
    function declareAnimal(address to, AnimalType race, Age age, Color color, uint rarity, bool isMale, bool canBreed)
        public onlyWhitelisted returns (bool) {
        _currentId++;
        Animal memory animal = Animal(_currentId, race, age, color, rarity, isMale, canBreed);
        _animalsOfOwner[msg.sender].push(animal);
        _animalsById[_currentId] = animal;
        _animalToOwner[_currentId] = to;
        mintToken(to, _currentId);
        return true;
    }

    // This function is reponsible for deleting an Animal but only the owner of the animal can do it 
      function deadAnimal(uint id) public onlyOwnerOfAnimal(id) {
        burnToken(msg.sender, id);
        _removeFromArray(msg.sender, id);
        delete _animalsById[id];
        delete _animalToOwner[id];
        emit AnimalDeleted(msg.sender, id);
    }


    function breedAnimals(uint senderId, uint targetId) public onlyWhitelisted onlyOwnerOfAnimal(senderId) returns (bool) {
        _checkingMinimumTwoCharacteristic(senderId,targetId);
        _creatingTheOffSpring(msg.sender, senderId, targetId);
        emit NewBorn(msg.sender, _currentId);
        return true;
    }
     // In order to know if a breeder can use our token , we call this function , require minimum two characteristic
    function _checkingMinimumTwoCharacteristic(uint senderId, uint targetId) private view {
        require(getApproved(targetId) == _animalToOwner[senderId], "target animal not approved");
        require(_sameRace(senderId, targetId), "not same race");
        require(_canBreed(senderId, targetId), "can't breed");
        require(_breedMaleAndFemale(senderId, targetId), "can't breed");
    }

    function _creatingTheOffSpring(address to, uint senderId, uint targetId) private {
        AnimalType race = _animalsById[senderId].race;
        Age age = Age.Young;
        Color color = _animalsById[senderId].color;
        uint rarity = _animalsById[senderId].rarity.add(_animalsById[targetId].rarity);
        bool isMale = _animalsById[targetId].isMale;
        bool canBreed = false;
        declareAnimal(to, race, age, color, rarity, isMale, canBreed);
    }
    function _sameRace(uint id1, uint id2) private view returns (bool) {
        return (_animalsById[id1].race == _animalsById[id2].race);
    }
    function _breedMaleAndFemale(uint id1, uint id2) private view returns (bool) {
        if ((_animalsById[id1].isMale) && (!_animalsById[id2].isMale)) return true;
        if ((!_animalsById[id1].isMale) && (_animalsById[id2].isMale)) return true;
        return false;
    }

    function _canBreed(uint id1, uint id2) private view returns (bool) {
        return (_animalsById[id1].canBreed && _animalsById[id2].canBreed);
    }

    //This function will create an Auction that Will stay 2 days as mentionned
    function createAuction(uint id, uint initialPrice) public onlyWhitelisted onlyOwnerOfAnimal(id) {
        require(!_auctionedAnimals[id], "already auctioned");
        _auctionedAnimals[id] = true;
        uint priceToBid = initialPrice.mul(_animalsById[id].rarity);
        _auctions[id] = Auction(msg.sender, address(0), now, initialPrice, priceToBid, 0);
        emit AuctionCreated(msg.sender, id);
    } 
    //Function to bid an Auctioned Animals
     function bidOnAuction(uint id, uint value) public onlyWhitelisted {
        require(msg.sender != _auctions[id].seller, "You bid on your own auction");
        require(_auctionedAnimals[id], "not an auctioned animal");
        require(value == _auctions[id].priceToBid, "not right price");
        _transferTokenBid(msg.sender, id, value);
        _updateAuction(msg.sender, id, value);
        emit NewBid(msg.sender, id, value);
    }
       function claimAuction(uint id) public onlyWhitelisted onlyAuctionedAnimal(id) {
        require(_auctions[id].lastBidder == msg.sender, "you are not the last bidder");
        require(_auctions[id].startDate + 2 days <= now, "2 days have not yet passed");
        _processRetrieveAuction(id);
        emit AuctionClaimed(msg.sender, id);
    }
    // This function will retreive the auction and will transfer the animal 
    function _processRetrieveAuction(uint id) private {
        Auction storage auction = _auctions[id];
        if (auction.lastBidder != address(0)) {
            _transferAnimal(auction.seller, auction.lastBidder, id);
            _auctionedAnimals[id] = false;
            delete _auctions[id];
        }  }
    // This methode is responsible for transfering the animal from the sender to the receiver 
    function _transferAnimal(address sender, address receiver, uint id) private onlyWhitelisted onlyOwnerOfAnimal(id) {
        require(_animalsById[id].id != 0, "not animal");
        require(!_auctionedAnimals[id], "auctioned animal");
        _transferFrom(sender, receiver, id);
        _removeFromArray(sender, id);
        _animalsOfOwner[receiver].push(_animalsById[id]);
        _animalToOwner[id] = receiver;
        emit AnimalTransfered(sender, receiver, id);
    }
    function _transferTokenBid(address newBidder, uint id, uint value) private {
        Auction memory auction = _auctions[id];
        if (auction.lastBidder != address(0)) {
            transferFrom(auction.seller, auction.lastBidder, auction.bestOffer);
        } else {
            transferFrom(newBidder, auction.seller, value);
        }
    }

     function _updateAuction(address newBidder, uint id, uint value) private {
        _auctions[id].lastBidder = newBidder;
        _auctions[id].priceToBid = _calculatepriceToBid(id);
        _auctions[id].bestOffer = value;
    }


    function _calculatepriceToBid(uint id) private view returns (uint) {
        return _auctions[id].priceToBid.mul(_animalsById[id].rarity);
    }
     function mintToken(address to, uint tokenId) public {
        _mint(to, tokenId);
    }
     /**
     * @dev Internal function to burn a specific token.
     * Reverts if the token does not exist.
     * Deprecated, use {_burn} instead.
     * @param owner owner of the token to burn
     * @param tokenId uint256 ID of the token being burned
     */
    function burnToken(address owner, uint tokenId) public {
        _burn(owner, tokenId);
    }
    //This function is reponsible for removing an id of an adress
       function _removeFromArray(address owner, uint id) private {
        uint size = _animalsOfOwner[owner].length;
        for (uint index = 0; index < size; index++) {
            Animal storage animal = _animalsOfOwner[owner][index];
            if (animal.id == id) {
                if (index < size - 1) {
                    _animalsOfOwner[owner][index] = _animalsOfOwner[owner][size - 1];
                }
                delete _animalsOfOwner[owner][size - 1];
            }
        }
    }

     function _burn(address _address, uint tokenId) internal {
        require(ownerOf(tokenId) == _address, "not owner of token");
        _clearApproval(tokenId);
        _ownedTokensCount[_address].decrement();
        _tokenOwner[tokenId] = address(0);
        emit Transfer(_address, address(0), tokenId);
    }
     /**
     * @dev Internal function to mint a new token.
     * Reverts if the given token ID already exists.
     * @param to The address that will own the minted token
     * @param tokenId uint256 ID of the token to be minted
     */
    function _mint(address to, uint tokenId) internal {
        require(to != address(0), "address 0x0");
        require(!_exists(tokenId), "token already exists");
        _tokenOwner[tokenId] = to;
        _ownedTokensCount[to].increment();
        emit Transfer(address(0), to, tokenId);
    }


     /**
     * @dev Safely transfers the ownership of a given token ID to another address
     * If the target address is a contract, it must implement `onERC721Received`,
     * which is called upon a safe transfer, and return the magic value
     * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
     * the transfer is reverted.
     * Requires the msg.sender to be the owner, approved, or operator
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes data to send along with a safe transfer check
     */
    function _safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) internal {
        _transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }
     /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * This is an internal detail of the `ERC721` contract and its use is deprecated.
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        internal returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }

        bytes4 retval = IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data);
        return (retval == _ERC721_RECEIVED);
    }


    /**
     * @dev Private function to clear current approval of a given token ID.
     * @param tokenId uint256 ID of the token to be transferred
     */
    function _clearApproval(uint256 tokenId) private {
        if (_tokenApprovals[tokenId] != address(0)) {
            _tokenApprovals[tokenId] = address(0);
        }
    }

/**
     * @dev Returns whether the given spender can transfer a given token ID.
     * @param spender address of the spender to query
     * @param tokenId uint256 ID of the token to be transferred
     * @return bool whether the msg.sender is approved for the given token ID,
     * is an operator of the owner, or is the owner of the token
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }
    /**
     * @dev Returns whether the specified token exists.
     * @param tokenId uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        address owner = _tokenOwner[tokenId];
        return owner != address(0);
    }
        /**
     * @dev Internal function to transfer ownership of a given token ID to another address.
     * As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
     */
    function _transferFrom(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _clearApproval(tokenId);

        _ownedTokensCount[from].decrement();
        _ownedTokensCount[to].increment();

        _tokenOwner[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

}