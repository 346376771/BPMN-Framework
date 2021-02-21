pragma solidity ^0.4.22;
pragma experimental ABIEncoderV2;


contract voteContract{


    event createVP(address contract_id,uint version_id);

    accessControl controlContract;
    constructor(address _addr) public{
        controlContract=accessControl(_addr);
    }

    uint proposalCount=0;
    uint[] proposalIds;
    mapping(uint=>Proposal) proposalMap;

    struct Proposal{
        uint id;
        address contractAddr;
        uint versionId;
        uint voteRequire;
        uint voteNow;
        uint voteMap;
        ProposalStatus proposalStatus;
    }

    enum ProposalStatus{Init,Pass}

    function addProposal(address _contract,uint versionId) public{
        uint id=++proposalCount;
        Proposal memory p=Proposal(id,_contract,versionId,controlContract.getParticipantlength(_contract),0,0,ProposalStatus.Init);
        proposalMap[id]=p;
        emit createVP(_contract,versionId);
    }

    function getProposalMsg(uint _id) public view returns(uint,address,uint,uint,uint,uint,ProposalStatus){
        Proposal storage p=proposalMap[_id];
        return (p.id,p.contractAddr,p.versionId,p.voteRequire,p.voteNow,p.voteMap,p.proposalStatus);

    }

    function voteProposal(uint _id) public{
        Proposal storage p=proposalMap[_id];
        uint id;
        uint weight;
        string memory des;
        string memory publicKey;
        (id,des,publicKey,weight)=controlContract.getParticipantMsg(p.contractAddr,msg.sender);
        require((p.proposalStatus==ProposalStatus.Init&&controlContract.getBitArr(p.voteMap,id)==0),"已投过票或提案不处于发起状态");
        p.voteMap=controlContract.changeBit(p.voteMap,id);
        p.voteNow=p.voteNow+weight;
        if(p.voteNow>=p.voteRequire){
            p.proposalStatus=ProposalStatus.Pass;
            Choreography c=Choreography(p.contractAddr);
            c.passVersion(p.versionId);
        }
    }

  



}