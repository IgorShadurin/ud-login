pragma solidity ^0.6.1;
pragma experimental ABIEncoderV2;

contract owned {
    address payable owner;
    constructor() public {owner = msg.sender;}

    // This contract only defines a modifier but does not use
    // it: it will be used in derived contracts.
    // The function body is inserted where the special symbol
    // `_;` in the definition of a modifier appears.
    // This means that if the owner calls this function, the
    // function is executed and otherwise, an exception is
    // thrown.
    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }
}

contract mortal is owned {
    // This contract inherits the `onlyOwner` modifier from
    // `owned` and applies it to the `close` function, which
    // causes that calls to `close` only have an effect if
    // they are made by the stored owner.
    function close() public onlyOwner {
        selfdestruct(owner);
    }
}

contract GetLogin is mortal {
    event EventStoreWallet(bytes32 indexed username, address indexed walletAddress, string ciphertext, string iv, string salt, string mac);
    event EventInviteCreated(bytes32 indexed creatorUsername, address inviteAddress);

    uint8 sessionMain = 1;
    uint8 sessionApp = 2;

    struct Username
    {
        bool isActive;
        // todo define a uniform variable name
        bytes32 username;
    }

    struct UserInfo
    {
        // todo define a uniform variable name
        bytes32 username;
        bool isActive;
    }

    struct InviteInfo
    {
        address inviteAddress;
        // todo define a uniform variable name
        bytes32 creatorUsername;
        bytes32 registeredUsername;
        bool isActive;
    }

    struct UserSession
    {
        // todo define a uniform variable name
        bytes32 username;
        address wallet;
        uint8 sessionType;
        uint64 appId;
    }

    struct Application
    {
        uint64 id;
        // todo define a uniform variable name
        bytes32 usernameHash;
        string title;
        string description;
        string[] allowedUrls;
        bool isActive;
    }

    uint64 public applicationId = 1;

    mapping(bytes32 => UserInfo) public Users;
    mapping(address => Username) public UsersAddressUsername;
    mapping(bytes32 => UserSession[]) public UserSessions;
    mapping(address => InviteInfo) public Invites;
    mapping(uint64 => Application) public Applications;

    modifier userRegistered {
        require(isAddressRegistered(msg.sender), "Only registered user can call this function");
        _;
    }

    constructor() public {
        bytes32 username = keccak256('admin');
        _createUser(username);
        uint64 newAppId = _createApplication(username, 'GetLogin', 'GetLogin - auth app');
        _addApplicationUrl(newAppId, 'https://localhost:3001');
    }

    /* Private methods */
    function _createUser(bytes32 usernameHash) private {
        // todo emit event?
        require(isUsernameExists(usernameHash) == false, "Username already used");
        require(isAddressRegistered(msg.sender) == false, "Wallet already used");
        Users[usernameHash] = UserInfo({username: usernameHash, isActive: true});
        UsersAddressUsername[msg.sender] = Username({username: usernameHash, isActive: true});
        //addMainSession(msg.sender);
        _addSessionInit(usernameHash, msg.sender, sessionMain, 0);
    }

    function _createApplication(bytes32 usernameHash, string memory title, string memory description) private returns (uint64) {
        // todo only main session can create and edit app?
        // todo emit event?
        string[] memory allowedUrls;
        Applications[applicationId] = Application({id: applicationId, usernameHash: usernameHash, title: title, description: description, allowedUrls: allowedUrls, isActive: true});
        applicationId++;

        return applicationId;
    }

    function _addApplicationUrl(uint64 appId, string memory url) private {
        // todo emit event?
        Applications[appId].allowedUrls.push(url);
    }

    function _deleteApplicationUrl(uint64 appId, uint index) private {
        // todo emit event?
        delete Applications[appId].allowedUrls[index];
    }

    function _addSessionInit(bytes32 usernameHash, address wallet, uint8 sessionType, uint64 appId) private {
        UserSessions[usernameHash].push(UserSession({username: usernameHash, wallet: wallet, sessionType: sessionType, appId: appId}));
    }

    function _addSession(address wallet, uint8 sessionType, uint64 appId) private {
        validateAppExists(appId);
        require(isAddressRegistered(wallet) == true, "Address already used");
        bytes32 usernameHash = getUsernameByAddress(wallet);
        UserSessions[usernameHash].push(UserSession({username: usernameHash, wallet: wallet, sessionType: sessionType, appId: appId}));
    }

    /* End of private methods */

    /* Validators */
    function validateAppOwner(uint64 appId, address wallet) public view userRegistered {
        require(isAppOwner(appId, wallet) == true, "You do not have access to this application");
    }

    function validateAppExists(uint64 appId) public view userRegistered {
        // todo return app info?
        getApplication(appId);
    }

    function validateInviteActive(address wallet) public view userRegistered {
        require(isActiveInvite(wallet) == true, "Invite not active");
    }

    /* End validators */


    /* Public methods */
    function createApplication(string memory title, string memory description) public userRegistered {
        bytes32 usernameHash = getUsernameByAddress(msg.sender);
        _createApplication(usernameHash, title, description);
    }

    function addApplicationUrl(uint64 appId, string memory url) public userRegistered {
        validateAppOwner(appId, msg.sender);
        _addApplicationUrl(appId, url);
    }

    function renameApplication(uint64 appId, string memory title, string memory description) public userRegistered {
        validateAppOwner(appId, msg.sender);
        Application storage app = Applications[appId];
        require(app.isActive == true, "App not found");
        app.title = title;
        app.description = description;
    }

    function deleteApplicationUrl(uint64 appId, uint index) public userRegistered {
        validateAppOwner(appId, msg.sender);
        _deleteApplicationUrl(appId, index);
    }

    function createUser(bytes32 usernameHash) public payable {
       _createUser(usernameHash);
    }

    function createInvite(address payable inviteAddress) public payable userRegistered {
        bytes32 creatorUsername = getUsernameByAddress(msg.sender);
        Invites[inviteAddress] = InviteInfo({inviteAddress: inviteAddress, creatorUsername: creatorUsername, registeredUsername: '', isActive: true});
        emit EventInviteCreated(creatorUsername, inviteAddress);
    }

    function createUserFromInvite(bytes32 usernameHash, address walletAddress, string memory ciphertext, string memory iv, string memory salt, string memory mac) public payable userRegistered {
       validateInviteActive(msg.sender);
       require(isAddressRegistered(walletAddress) == false, "Address already registered");
       InviteInfo storage invite = Invites[msg.sender];
       createUser(usernameHash);
       emit EventStoreWallet(usernameHash, walletAddress, ciphertext, iv, salt, mac);
       invite.isActive = false;
       invite.registeredUsername = usernameHash;
    }

    function addAppSession(address wallet, uint64 appId) public payable userRegistered {
        // todo check only one main session possible
        // todo hide user apps ids?
        _addSession(wallet, sessionApp, appId);
    }

    function addMainSession(address wallet) public payable userRegistered {
        _addSession(wallet, sessionApp, 0);
    }

    /* End of public methods */

    /* View methods */
    function getApplication(uint64 id) public view returns (Application memory) {
        Application memory app = Applications[id];
        require(app.isActive == true, "App not found");

        return app;
    }

    function getUserInfo(bytes32 usernameHash) public view returns (UserInfo memory) {
        return Users[usernameHash];
    }

    function isUsernameExists(bytes32 usernameHash) public view returns (bool) {
        return getUserInfo(usernameHash).isActive == true;
    }

    function isAddressRegistered(address wallet) public view returns (bool) {
        Username memory currentUser = UsersAddressUsername[wallet];
        if(currentUser.isActive != true){
            return false;
        }

        return Users[currentUser.username].isActive == true;
    }

    function isAppOwner(uint64 appIp, address checkAddress) public view returns (bool) {
        bytes32 currentUsernameHash = getUsernameByAddress(checkAddress);
        return getApplication(appIp).usernameHash == currentUsernameHash;
    }

    function getUserByAddress(address wallet) public view returns (UserInfo memory) {
        Username memory currentUser = UsersAddressUsername[wallet];
        require(currentUser.isActive == true, "User with this address not found");
        return Users[currentUser.username];
    }

    function getUsernameByAddress(address wallet) public view returns (bytes32) {
        return getUserByAddress(wallet).username;
    }

    function isActiveInvite(address wallet) public view returns (bool) {
        return Invites[wallet].isActive == true;
    }

    function getInvite(address wallet) public view returns (InviteInfo memory) {
        return Invites[wallet];
    }

    /* End of view methods */
}
