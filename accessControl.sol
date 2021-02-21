pragma solidity ^0.4.22;
pragma experimental ABIEncoderV2;


contract accessControl{


    struct Role{
        //角色 id
        string id;
        //角色描述
        string des;
        //角色映射
        uint participantJudge;
    }

    struct Participant{
        //参与者id
        uint id;
        //参与者描述
        string des;
        //参与者公钥
        string publicKey;
        //权重
        uint weight;
    }

    struct BpmContract{
        //合约模型的名称
        string name;
        //元素数组
        string[] roleIds;
        //角色映射
        mapping(string=>Role) roleMap;
        //参与者数组
        address[] participant;
        //参与者映射
        mapping(address=>Participant) participantMap;
    }

    address[] BpmContractAddrs;
    mapping(address=>BpmContract) BpmContractMap;

    function newBpmContract(address _addr,string _name) public{
        BpmContractAddrs.push(_addr);
        BpmContractMap[_addr].name=_name;
    }



    modifier checkBpmContract(address _addr)  {
         require(bytes(BpmContractMap[_addr].name).length>0, "不存在该流程合约");
         _;
    }

    modifier checkRole(address _addr,string _roleId)  {
         require(bytes(BpmContractMap[_addr].roleMap[_roleId].id).length!=0, "该角色不存在");
         _;
    }

    modifier checkParticipant(address _addr,address _participantAddr)  {
         require(BpmContractMap[_addr].participantMap[_participantAddr].id!=0, "该参与者不存在");
         _;
    }

    

    //新增角色
    function addRole(address _addr,string _roleId,string _des) public  checkBpmContract(_addr) {
        //require(bytes(BpmContractMap[_addr].name).length>0, "不存在该流程合约");
        BpmContract storage  bpmContract=BpmContractMap[_addr];
        require( bytes(bpmContract.roleMap[_roleId].id).length ==0, "该角色已存在");
        bpmContract.roleIds.push(_roleId);
        bpmContract.roleMap[_roleId]=Role(_roleId,_des,0);
    }

    //校验角色是否存在
    function isRoleExist(address _addr,string _roleId) public view returns(bool){
        if(bytes(BpmContractMap[_addr].name).length==0||bytes(BpmContractMap[_addr].roleMap[_roleId].id).length==0){
            return false;
        }else{
            return true;
        }
    }

    //新增用户
    function addParticipant(address _addr,address _participantAddr,string _des,string _publicKey) public checkBpmContract(_addr)  {
        //require(bytes(BpmContractMap[_addr].name).length>0, "不存在该流程合约");
        BpmContract storage  bpmContract=BpmContractMap[_addr];
        require(bpmContract.participantMap[_participantAddr].id==0, "该参与者已存在");
        uint id=bpmContract.participant.length+1;
        bpmContract.participant.push(_participantAddr);
        bpmContract.participantMap[_participantAddr]=Participant(id,_des,_publicKey,1);
    }

    //修改用户权重
    function changeParticipantWeight(address _contractAddr,address _participantAddr,uint weight) public{
        require(isParticipantExist(_contractAddr, _participantAddr), "不存在该流程合约或参与者");
        Participant storage p=BpmContractMap[_contractAddr].participantMap[_participantAddr];
        p.weight=weight;
    }

    function getParticipantMsg(address _contractAddr,address _participantAddr) public view returns(uint,string,string,uint){
        require(isParticipantExist(_contractAddr, _participantAddr), "不存在该流程合约或参与者");
        Participant storage p=BpmContractMap[_contractAddr].participantMap[_participantAddr];
        return (p.id,p.des,p.publicKey,p.weight);
    }

   /*  function getParticipantId(address _contractAddr,address _participantAddr) public view returns(uint){
        require(isParticipantExist(_contractAddr, _participantAddr), "不存在该流程合约或参与者");
        Participant storage p=BpmContractMap[_contractAddr].participantMap[_participantAddr];
        return p.id;
    }

     function getParticipantWeight(address _contractAddr,address _participantAddr) public view returns(uint){
        require(isParticipantExist(_contractAddr, _participantAddr), "不存在该流程合约或参与者");
        Participant storage p=BpmContractMap[_contractAddr].participantMap[_participantAddr];
        return p.weight;
    } */
    
    //校验用户是否存在
    function isParticipantExist(address _addr,address _participantAddr) public view returns(bool){
        if(bytes(BpmContractMap[_addr].name).length==0||BpmContractMap[_addr].participantMap[_participantAddr].id==0){
            return false;
        }else{
            return true;
        }
    }

    
    function allocationRole(address _addr,address _participantAddr,string _roleId) public checkBpmContract(_addr) checkRole(_addr,_roleId) checkParticipant(_addr,_participantAddr){
        require(getBitArr(BpmContractMap[_addr].roleMap[_roleId].participantJudge,BpmContractMap[_addr].participantMap[_participantAddr].id)==0, "该用户已经拥有该权限");
        BpmContractMap[_addr].roleMap[_roleId].participantJudge=changeBit(BpmContractMap[_addr].roleMap[_roleId].participantJudge,BpmContractMap[_addr].participantMap[_participantAddr].id);
    }

    function removeRole(address _addr,address _participantAddr,string _roleId) public checkBpmContract(_addr) checkRole(_addr,_roleId) checkParticipant(_addr,_participantAddr){
        require(getBitArr(BpmContractMap[_addr].roleMap[_roleId].participantJudge,BpmContractMap[_addr].participantMap[_participantAddr].id)==1, "该用户没有该权限");
        BpmContractMap[_addr].roleMap[_roleId].participantJudge=changeBit(BpmContractMap[_addr].roleMap[_roleId].participantJudge,BpmContractMap[_addr].participantMap[_participantAddr].id);
    }


    function judgeParticipantRole(address _addr,address _participantAddr,string _roleId) public view  checkBpmContract(_addr) checkRole(_addr,_roleId) checkParticipant(_addr,_participantAddr) returns(bool){
        return getBitArr(BpmContractMap[_addr].roleMap[_roleId].participantJudge,BpmContractMap[_addr].participantMap[_participantAddr].id)==1;
    }


    function getContractData(address _addr) public view checkBpmContract(_addr) returns(string name,string[] roles,address[] participant) {
        return (BpmContractMap[_addr].name,BpmContractMap[_addr].roleIds,BpmContractMap[_addr].participant);
    }

    function getParticipantlength(address _addr) public view returns(uint){
        return BpmContractMap[_addr].participant.length;
    }






    /* 工具函数 */ 
   //获取一个uint256数特定位的数字0或1
    function getBitArr(uint i,uint bit) public pure returns(uint){
       return (i>>(bit-1))&1;
   }
   
   //修改uint数特定位的数字
   function changeBit(uint i,uint bit) public pure returns(uint){
       return i^(1<<(bit-1));
   }


}
