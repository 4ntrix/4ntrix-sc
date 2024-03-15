// SPDX-License-Identifier: UNLICENSED

// Solidity version declaration
pragma solidity ^0.8.9;

// Importing required contracts from OpenZeppelin library
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Main contract definition inheriting from ERC721 and Ownable
contract Antrix is ERC721, Ownable {
    // State variables
    uint256 public totalOccasions; // Total number of occasions listed
    uint256 public totalSupply; // Total number of tickets sold
    uint256 public constant MAX_TICKETS_PER_ADDRESS = 5; // Maximum tickets allowed per address

    // Struct for an occasion
    struct Occasion {
        uint256 id; // Unique identifier for the occasion
        string name; // Name of the occasion
        uint256 cost; // Cost of each ticket
        uint256 tickets; // Remaining tickets available for the occasion
        uint256 maxTickets; // Maximum tickets allowed for the occasion
        string date; // Date of the occasion
        string time; // Time of the occasion
        string location; // Location of the occasion
        string ipfsImageHash; // IPFS hash of the occasion's image
    }

    // Struct for a user
    struct User {
        string name; // Name of the user
        string aadharCard; // Aadhar card of the user
        string ipfsImageHash; // IPFS hash of the user's image
    }

    // Mappings to store data
    mapping(uint256 => Occasion) public occasions; // Mapping from occasion ID to Occasion struct
    mapping(uint256 => mapping(address => bool)) public hasBought; // Mapping to check if an address has bought tickets for an occasion
    mapping(uint256 => mapping(uint256 => address)) public seatTaken; // Mapping to check if a seat is taken for an occasion
    mapping(uint256 => uint256[]) public seatsTaken; // Mapping to store seats taken for each occasion
    mapping(address => User) public users; // Mapping from user address to User struct

    // Events
    event OccasionListed(uint256 indexed id, string name, uint256 cost, uint256 maxTickets, string date, string time, string location, string ipfsImageHash);
    event TicketsPurchased(address indexed buyer, uint256 indexed occasionId, uint256 ticketId);
    event AttendanceMarked(address indexed attendee, uint256 indexed occasionId);

    // Modifier to restrict access to only admins or owner
    modifier onlyAdminOrOwner() {
        require(owner() == msg.sender || admins[msg.sender], "Caller is not an admin or owner");
        _;
    }

    // Mapping to store admins
    mapping(address => bool) public admins;

    // Constructor to initialize the contract
    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC721(_name, _symbol) Ownable(_owner) {
        admins[_owner] = true; // Owner is set as admin
    }

    // Function to add a new admin
    function addAdmin(address _admin) external onlyOwner {
        admins[_admin] = true;
    }

    // Function to remove an admin
    function removeAdmin(address _admin) external onlyOwner {
        require(_admin != owner(), "Cannot remove owner as admin");
        admins[_admin] = false;
    }

    // Function to list a new occasion
    function list(
        string memory _name,
        uint256 _cost,
        uint256 _maxTickets,
        string memory _date,
        string memory _time,
        string memory _location,
        string memory _ipfsImageHash
    ) public onlyAdminOrOwner {
        totalOccasions++; // Increment total occasions
        // Add occasion to occasions mapping
        occasions[totalOccasions] = Occasion(
            totalOccasions,
            _name,
            _cost,
            _maxTickets,
            _maxTickets,
            _date,
            _time,
            _location,
            _ipfsImageHash
        );

        // Emit event for occasion listed
        emit OccasionListed(totalOccasions, _name, _cost, _maxTickets, _date, _time, _location, _ipfsImageHash);
    }

    // Function to mint tickets
    function mint(uint256 _id, uint256 _seat) public payable {
        require(_id != 0, "Invalid occasion ID");
        require(_id <= totalOccasions, "Occasion does not exist");

        Occasion storage occasion = occasions[_id];
        require(msg.value >= occasion.cost, "Insufficient payment");

        require(_seat <= occasion.maxTickets, "Invalid seat");

        require(occasion.tickets > 0, "Tickets sold out");

        require(getNumTicketsPurchased(msg.sender) + 1 <= MAX_TICKETS_PER_ADDRESS, "Exceeded maximum tickets per address");

        require(seatTaken[_id][_seat] == address(0), "Seat already taken");

        occasions[_id].tickets--;
        hasBought[_id][msg.sender] = true;
        seatTaken[_id][_seat] = msg.sender;
        seatsTaken[_id].push(_seat);
        totalSupply++;

        _safeMint(msg.sender, totalSupply);

        emit TicketsPurchased(msg.sender, _id, totalSupply);
    }

    // Function to mark attendance by admin or owner
    function markAttendance(uint256 _id, address _attendee) public onlyAdminOrOwner {
        require(_id != 0, "Invalid occasion ID");
        require(_id <= totalOccasions, "Occasion does not exist");
        require(hasBought[_id][_attendee], "Address has not bought a ticket for this occasion");

        hasBought[_id][_attendee] = true;

        emit AttendanceMarked(_attendee, _id);
    }

    // Function to set occasion details
    function setOccasionDetails(
        uint256 _id,
        string memory _name,
        uint256 _cost,
        uint256 _maxTickets,
        string memory _date,
        string memory _time,
        string memory _location
    ) external onlyAdminOrOwner {
        require(_id != 0, "Invalid occasion ID");
        require(_id <= totalOccasions, "Occasion does not exist");

        Occasion storage occasion = occasions[_id];

        for (uint256 i = 1; i <= totalOccasions; i++) {
            if (i != _id) {
                require(keccak256(abi.encodePacked(occasions[i].name)) != keccak256(abi.encodePacked(_name)), "Cannot set occasion details to existing occasion's name");
            }
        }

        occasion.name = _name;
        occasion.cost = _cost;
        occasion.maxTickets = _maxTickets;
        occasion.date = _date;
        occasion.time = _time;
        occasion.location = _location;
    }

    // Function to withdraw contract balance
    function withdraw() public onlyAdminOrOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    // Function to transfer ownership
    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
        admins[owner()] = false;
        admins[newOwner] = true;
    }

    // Function to get number of tickets purchased by a user
    function getNumTicketsPurchased(address _address) public view returns (uint256) {
        uint256 numTickets = 0;
        for (uint256 i = 1; i <= totalOccasions; i++) {
            if (hasBought[i][_address]) {
                numTickets++;
            }
        }
        return numTickets;
    }

    // Function to get occasion details
    function getOccasion(uint256 _id) public view returns (Occasion memory) {
        return occasions[_id];
    }

    // Function to get seats taken for an occasion
    function getSeatsTaken(uint256 _id) public view returns (uint256[] memory) {
        return seatsTaken[_id];
    }

    // Function to add a new user
    function addUser(string memory _name, string memory _aadharCard, string memory _ipfsImageHash) public {
        users[msg.sender] = User(_name, _aadharCard, _ipfsImageHash);
    }

    // Function to get user details
    function getUser(address _userAddress) public view returns (User memory) {
        return users[_userAddress];
    }

    // Function to get all occasions
    function getAllOccasions() public view returns (Occasion[] memory) {
        Occasion[] memory allOccasions = new Occasion[](totalOccasions);
        for (uint256 i = 1; i <= totalOccasions; i++) {
            allOccasions[i - 1] = occasions[i];
        }
        return allOccasions;
    }

    // Function to get all users
    function getAllUsers() public view returns (User[] memory) {
        User[] memory allUsers = new User[](totalSupply);
        for (uint256 i = 1; i <= totalSupply; i++) {
            allUsers[i - 1] = users[ownerOf(i)];
        }
        return allUsers;
    }
}
