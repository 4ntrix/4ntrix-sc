// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Antrix is ERC721, Ownable {
    uint256 public totalOccasions;
    uint256 public totalSupply;
    uint256 public constant MAX_TICKETS_PER_ADDRESS = 5;

    struct Occasion {
        uint256 id;
        string name;
        uint256 cost;
        uint256 tickets;
        uint256 maxTickets;
        string date;
        string time;
        string location;
        string ipfsImageHash;
    }

    struct User {
        string name;
        string aadharCard;
        string ipfsImageHash;
    }

    mapping(uint256 => Occasion) public occasions;
    mapping(uint256 => mapping(address => bool)) public hasBought;
    mapping(uint256 => mapping(uint256 => address)) public seatTaken;
    mapping(uint256 => uint256[]) public seatsTaken;
    mapping(address => User) public users;

    event OccasionListed(uint256 indexed id, string name, uint256 cost, uint256 maxTickets, string date, string time, string location, string ipfsImageHash);
    event TicketsPurchased(address indexed buyer, uint256 indexed occasionId, uint256 ticketId);
    event AttendanceMarked(address indexed attendee, uint256 indexed occasionId);

    modifier onlyAdminOrOwner() {
        require(owner() == msg.sender || admins[msg.sender], "Caller is not an admin or owner");
        _;
    }

    mapping(address => bool) public admins;

    constructor(
        address _owner
    ) ERC721("Antrix", "ANT") Ownable(_owner) {
        admins[_owner] = true;
    }

    function addAdmin(address _admin) external onlyOwner {
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(_admin != owner(), "Cannot remove owner as admin");
        admins[_admin] = false;
    }

    function list(
        string memory _name,
        uint256 _cost,
        uint256 _maxTickets,
        string memory _date,
        string memory _time,
        string memory _location,
        string memory _ipfsImageHash
    ) public onlyAdminOrOwner {
        totalOccasions++;
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

        emit OccasionListed(totalOccasions, _name, _cost, _maxTickets, _date, _time, _location, _ipfsImageHash);
    }

    function mint(uint256 _id, uint256 _seat, uint256 _ticketCost) public payable {
        require(_id != 0, "Invalid occasion ID");
        require(_id <= totalOccasions, "Occasion does not exist");

        Occasion storage occasion = occasions[_id];
        require(occasion.tickets > 0, "Tickets sold out");
        require(occasion.tickets >= _seat, "Invalid seat");

        require(getNumTicketsPurchased(msg.sender) + 1 <= MAX_TICKETS_PER_ADDRESS, "Exceeded maximum tickets per address");
        require(occasion.cost > 0, "Ticket cost not set");

        require(seatTaken[_id][_seat] == address(0), "Seat already taken");

        // Check if user sent enough ether for the ticket
        require(msg.value >= _ticketCost, "Insufficient payment");

        occasions[_id].tickets--;
        hasBought[_id][msg.sender] = true;
        seatTaken[_id][_seat] = msg.sender;
        seatsTaken[_id].push(_seat);
        totalSupply++;

        _safeMint(msg.sender, totalSupply);

        // Refund excess payment
        uint256 excessPayment = msg.value - _ticketCost;
        if (excessPayment > 0) {
            payable(msg.sender).transfer(excessPayment);
        }

        emit TicketsPurchased(msg.sender, _id, totalSupply);
    }


    function markAttendance(uint256 _id, address _attendee) public onlyAdminOrOwner {
        require(_id != 0, "Invalid occasion ID");
        require(_id <= totalOccasions, "Occasion does not exist");
        require(hasBought[_id][_attendee], "Address has not bought a ticket for this occasion");

        hasBought[_id][_attendee] = true;

        emit AttendanceMarked(_attendee, _id);
    }

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

    function withdraw() public onlyAdminOrOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
        admins[owner()] = false;
        admins[newOwner] = true;
    }

    function getNumTicketsPurchased(address _address) public view returns (uint256) {
        uint256 numTickets = 0;
        for (uint256 i = 1; i <= totalOccasions; i++) {
            if (hasBought[i][_address]) {
                numTickets++;
            }
        }
        return numTickets;
    }

    function getOccasion(uint256 _id) public view returns (Occasion memory) {
        return occasions[_id];
    }

    function getSeatsTaken(uint256 _id) public view returns (uint256[] memory) {
        return seatsTaken[_id];
    }

    function addUser(string memory _name, string memory _aadharCard, string memory _ipfsImageHash) public {
        users[msg.sender] = User(_name, _aadharCard, _ipfsImageHash);
    }

    function getUser(address _userAddress) public view returns (User memory) {
        return users[_userAddress];
    }

    function getAllOccasions() public view returns (Occasion[] memory) {
        Occasion[] memory allOccasions = new Occasion[](totalOccasions);
        for (uint256 i = 1; i <= totalOccasions; i++) {
            allOccasions[i - 1] = occasions[i];
        }
        return allOccasions;
    }

    function getAllUsers() public view returns (User[] memory) {
        User[] memory allUsers = new User[](totalSupply);
        for (uint256 i = 1; i <= totalSupply; i++) {
            allUsers[i - 1] = users[ownerOf(i)];
        }
        return allUsers;
    }
}
