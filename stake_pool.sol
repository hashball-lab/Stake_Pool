// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ERC721 {
    function safeTransferFrom(address from, address to, uint256 id, bytes memory data) external;
}

contract StakePool {

    ERC721 public NFTToken;

    uint256 private totalNFTNum;
    uint256 private totalBonusAmount;
    uint256 private lastDistrAmount;
    //Funds come in, effect totalbonusAmount;
    //User come in, effect lastDistrAmount, totalNFTNum;
    uint256 private totalAverageAmount;
    mapping(uint256 => uint256) private claimBonusAmount;
    mapping(uint256 => uint256) private alreadyTotalAverageAmount;//tokenID
    mapping(address => uint256[]) private addressToTokenID;
    mapping(uint256 => address) private idToOwner;
    address private owner;   
    bool private initialized;

    struct StakeInfo{
        uint256 token_id;
        uint256 claimed_amount;
        uint256 claimable_amount;
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "not owner");
        _;
    }

    function initialize(address _owner) public{
        require(!initialized, "already initialized");
        initialized = true;
        owner = _owner;
        totalNFTNum = 0;
    }

    function set_nft_address(address _nfttoken) public onlyOwner{
        NFTToken = ERC721(_nfttoken);
    }

    function stakeNFT(uint256 _id) public{//id
        NFTToken.safeTransferFrom(msg.sender, address(this), _id, "");
        uint256 currentAverageAmount;
        if(totalBonusAmount == 0){
            currentAverageAmount = 0;
        }else{
            if(totalNFTNum == 0){
                currentAverageAmount = 0;
            }else{
                currentAverageAmount = (totalBonusAmount - lastDistrAmount) / totalNFTNum;
            }            
        }
        totalAverageAmount += currentAverageAmount;
        if(totalNFTNum == 0){
            lastDistrAmount = 0;
        }else{
            lastDistrAmount = totalBonusAmount;
        }
        alreadyTotalAverageAmount[_id] = totalAverageAmount;
        claimBonusAmount[_id] = 0;
        addressToTokenID[msg.sender].push(_id);
        idToOwner[_id] = msg.sender;
        totalNFTNum ++;
    }

    function removeNFT(uint256 _id) public{
        require(idToOwner[_id] == msg.sender, "not owner");
        NFTToken.safeTransferFrom(address(this), msg.sender, _id, "");
        uint256 currentAverageAmount;
        if(totalBonusAmount == 0){
            currentAverageAmount = 0;
        }else{
            if(totalNFTNum == 0){
                currentAverageAmount = 0;
            }else{
                currentAverageAmount = (totalBonusAmount - lastDistrAmount) / totalNFTNum;
            }            
        }
        totalAverageAmount += currentAverageAmount;
        if(totalNFTNum == 0){
            lastDistrAmount = 0;
        }else{
            lastDistrAmount = totalBonusAmount;
        }
        idToOwner[_id] = address(0);
        // caculate claim amount
        uint256 available_claim_amount = totalAverageAmount - alreadyTotalAverageAmount[_id] - claimBonusAmount[_id];
        (bool success, ) = (msg.sender).call{value: available_claim_amount}("");
        if(!success){
            revert('call failed');
        }
        //pop id 
        uint256 len = addressToTokenID[msg.sender].length;
        for(uint256 i =0; i<len; i++){
            if(addressToTokenID[msg.sender][i] == _id){
                addressToTokenID[msg.sender][i] = addressToTokenID[msg.sender][len - 1];
                addressToTokenID[msg.sender].pop();
                i=len;
            }
        }
        if(totalNFTNum > 1){
            totalNFTNum = totalNFTNum - 1;
        }
    }

    function claimReward(uint256 _id) public {
        require(idToOwner[_id] == msg.sender, "not owner");
        uint256 available_claim_amount = getbonusAmountByID(_id);
        require(available_claim_amount > 0, 'no reward');
        claimBonusAmount[_id] += available_claim_amount;
        (bool success, ) = (msg.sender).call{value: available_claim_amount}("");
        if(!success){
            revert('call failed');
        }
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external pure returns (bytes4){
       return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
        // return this.onERC721Received.selector;//same
    }

    receive() external payable {
        totalBonusAmount += msg.value;
    }
    fallback() external payable {}

    function getbonusAmountByID(uint256 _id) public view returns(uint256){
        if(idToOwner[_id] == address(0)){
            return 0;
        }
        uint256 currentAverageAmount;
        if(totalBonusAmount == 0){
                currentAverageAmount = 0;
        }else{
                if(totalNFTNum == 0){
                    currentAverageAmount = totalBonusAmount;

                }else{
                    currentAverageAmount = (totalBonusAmount - lastDistrAmount) / totalNFTNum;
                }
        }

        return (currentAverageAmount + totalAverageAmount - alreadyTotalAverageAmount[_id] - claimBonusAmount[_id]);
    }

    function get_currentAverageAmount_totalAverageAmount() public view returns(uint256, uint256){
        uint256 currentAverageAmount;
        if(totalBonusAmount == 0){
            currentAverageAmount = 0;
        }else{
            if(totalNFTNum == 0){
                currentAverageAmount = totalBonusAmount;

            }else{
                currentAverageAmount = (totalBonusAmount - lastDistrAmount) / totalNFTNum;
            }
        }
        return (currentAverageAmount, totalAverageAmount);
    }

    function get_deposite_id(address addr) public view returns(uint256[] memory){
        return addressToTokenID[addr];
    }
    function get_total_bonus_amount_and_nftnum() public view returns(uint256, uint256){
        return (totalBonusAmount, totalNFTNum);
    }
    function get_stake_info(address addr) public view returns(StakeInfo[] memory){
        uint256 len = addressToTokenID[addr].length;
        StakeInfo[] memory stakeinfos = new StakeInfo[](len);
        for(uint256 i = 0; i < len; i++){
            stakeinfos[i] = StakeInfo(addressToTokenID[addr][i], claimBonusAmount[addressToTokenID[addr][i]], getbonusAmountByID(addressToTokenID[addr][i]));
        }
        return stakeinfos;
    }

}
