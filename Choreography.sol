pragma solidity ^0.4.22;
pragma experimental ABIEncoderV2;


contract Choreography{

    event sendMes(uint instance_id,uint message_id,address receiver);
    event finishTask(uint instance_id,uint element_id);

    //访问控制合约
    accessControl acl;
    //投票合约
    voteContract vote;

    //构造函数，在创建编排合约时需要传入访问控制和投票合约的地址
    constructor(address acl_addr,address vote_addr,string _name) public {
        acl=accessControl(acl_addr);
        vote=voteContract(vote_addr);
        acl.newBpmContract(this,_name);
    }

    /* ------------------------------------------------------------------------------------------------ */
    /* 以下为合约的数据部分，即编排图可以由元素信息以及消息的信息构成  */
    //数据信息,根据元素的类别大致分为三类 事件(开始、结束)  编排任务（信息的交互） 网关(并行、排他)
    enum ElementType{Start,End,ChoreographyTask,Parallel,Exclusive,EventBased}

    //元素数量
    uint count=0;
    
    struct Element{
        //元素id，元素主键，一旦创建不可修改
        uint id;
        //版本数 初始化为1 后续每个元素可以派生出很多个版本
        uint version;
        //具体每个版本的元素的结构
        mapping(uint=>ElementStruct) versionMap;
    }

    struct ElementStruct{
        /* 通用结构 */
        //元素的名称
        string name;
        //元素的类型
        ElementType elementType;
        //前驱任务
        uint[] preElements;
        //后继任务
        uint[] nextElements;

        /* 任务特有结构 */
        //元素的发起人
        string initParticipant;
        //元素的参与者
        string[] participant;
        //元素执行需要的消息
        uint[] messages;
        //元素的互斥集合
        uint[] exclusiveIds;
        //决策id
        uint decisionId;
    }

    //id映射到的实际元素 
    mapping(uint=>Element) elementMap;

    //增加元素，增加的是模型的元素数据
    function addElement(uint _id,string _name,ElementType _elementType,string _initParticipant,string[] _participant,uint[] _messages,uint[] _preElements,uint[] _nextElements,uint[] _exclusiveIds,uint _decisionId) public{
        //id必须从1开始，而且必须是自增的所以不能大于count+1，即count=2有两个元素 下一个只能是1-3之间
        require(_id>0&&_id<=count+1,"id必须从1开始,且必须是自增的");
        //当前元素的id不存在，说明是创建新的元素
        Element storage e=elementMap[_id];
        //如果等于0说明现在还没有 创建第一个，不然就是在原来基础上更新
        if(e.id==0){
            e.id=_id;
            e.version=1;
            count++;
        }else{
            //元素的id存在，是在原来元素的基础上更新一个版本
            e.version++;   
        }
        //创建元素的结构体绑定在版本号上
        ElementStruct memory es=ElementStruct(_name,_elementType,_preElements,_nextElements,_initParticipant,_participant,_messages,_exclusiveIds,_decisionId);
        e.versionMap[e.version]=es;
        
    }

    //获取元素的名称、类型，发起人角色、参与者角色、前驱元素数组、后继元素数据，消息数组，传入值为元素id和版本号 (i_id,v_id)唯一确定一个元素的结构体
    function getElement(uint _id,uint _version) public view returns(string,ElementType,string,string[],uint[],uint[],uint[],uint){
        require(_id>0&&_version>0&&elementMap[_id].id!=0&&elementMap[_id].version>=_version,"传入参数有误或者元素或者版本不存在");
        ElementStruct storage es=elementMap[_id].versionMap[_version];
        return (es.name,es.elementType,es.initParticipant,es.participant,es.messages,es.preElements,es.nextElements,es.decisionId);
    }

    enum Operator{LESS,GREATER,EQUAL,NEQ,LEQ,GEQ,ELEMENT,True,False}
    enum DecisionType{StringTyp,IntTyp,BoolTyp}
    struct Decision{
        uint decisionId;
        DecisionType decisionType;
        Operator operator;
        uint task;
        uint versionId;
        string variableName;
        uint[] intCondition;
        string stringCondition;
    }

    

    uint decisionCount=0;
    mapping(uint=>Decision) decisionMap;

    function addDecision(DecisionType _decisionType,Operator _operator,uint _task,uint _versionId,string _variableName,uint[] _intCondition,string _stringCondition) public {
        uint countNow=++decisionCount;
        Decision storage d=decisionMap[countNow];
        d.decisionId=countNow;
        d.decisionType=_decisionType;
        d.operator=_operator;
        d.task=_task;
        d.versionId=_versionId;
        d.variableName=_variableName;
        if(_intCondition.length!=0){
            d.intCondition=_intCondition;
        }else{
            d.stringCondition=_stringCondition;
        }
    }

    function getDecision(uint _id) public view returns(uint,DecisionType,Operator,uint,uint,string,uint[],string){
        Decision storage d=decisionMap[_id];
        return (d.decisionId,d.decisionType,d.operator,d.task,d.versionId,d.variableName,d.intCondition,d.stringCondition);
    }

    uint messageCount=0;
    //设置消息的类型是请求还是回复 请求是任务发起者的消息,回复是two-way任务中的回复消息 
    //同一个编排任务当中如果存在回复和请求的消息的情况下，回复必须在请求消息之后发出 即同一个编排任务内的消息交互顺序 
    enum MessageType{Request,Reply}
    struct Message{
        //消息id
        uint id;
        //版本数 从1开始，0留空
        uint version;
        //版本映射
        mapping(uint=>MessageStruct) versionMap;

    }

    struct MessageStruct{
        //消息名称
        string name;
        //消息的类别
        MessageType messageType;
        //消息的发起人
        string sender;
        //消息的接受人
        string receiver;
        //消息所属任务
        uint task;
        //消息中带有的变量名
        string[] valName;
        //消息的内容
        mapping(string=>string) valTypeMap;
    }
    mapping(uint=>Message) messageMap;

    //新增模型数据中的消息结构
    function addMessage(uint _id,string _name,MessageType _messageType,string _sender,string _receiver,uint _task,string[] _valName,string[] _valType) public{
        require(_id>0&&_id<=messageCount+1,"消息id必须从正数开始");
        require(_valName.length==_valType.length,"变量名和变量值必须对应");
        //消息的
        Message storage m=messageMap[_id];
        //如果为0 说明还没有版本，初始化第一个版本
        if(m.id==0){
            m.id=_id;
            m.version=1;
            messageCount++;
        }else{
            m.version++;
        }
        //如果对应的消息的接收和发送者的角色在访问控制合约中不存在，则直接添加
        /* if(!acl.isRoleExist(this,_sender)){
            acl.addRole(this,_sender,_sender);
        }
        if(!acl.isRoleExist(this,_receiver)){
            acl.addRole(this,_receiver,_receiver);
        } */
        //初始化消息结构
        MessageStruct storage ms=m.versionMap[m.version];
        ms.name=_name;
        ms.messageType=_messageType;
        ms.sender=_sender;
        ms.receiver=_receiver;
        ms.task=_task;
        ms.valName=_valName;
        for(uint i=0;i<_valName.length;i++){
            ms.valTypeMap[_valName[i]]=_valType[i];
        }
    }
    
    //获取消息信息 消息由消息id和版本id共同组成(m_id,v_id)唯一确定一个消息，获取消息的消息名称、消息类别、发起人角色、接收人角色、消息所属编排任务
    function getMessage(uint _id,uint _version) public view returns(string,MessageType,string,string,uint,string[]){
        require(_id>0&&_version>0&&messageMap[_id].id!=0&&messageMap[_id].version>=_version,"传入参数有误或者不存在相应版本的消息");
        MessageStruct storage ms=messageMap[_id].versionMap[_version];
        return (ms.name,ms.messageType,ms.sender,ms.receiver,ms.task,ms.valName);
    }


    /* ------------------------------------------------------------------------------------------------------------------------------- */
    /* 下面为版本的结构体,版本由上述的合约元素和消息以及部分额外的信息组成 */
    uint public versionNum=0;
    //注意数组的下标对应的是相应元素的映射(需要错开一位 元素和消息的0位置用于判null)，
    //即elementVersion[0] 对应的 id为（0+1）的元素版本信息
    //例：elementVersion[0]=2 ===》当前版本对于采用id为1的元素的使用2号版本 
    struct Version{
        //版本号从1开始，0留空
        uint id;
        //元素版本数组
        uint[] elementVersion;
        //消息版本数组
        uint[] messageVersion;
        //版本的开始事件,具体版本号存储在元素的版本数组中
        uint start;
        //版本状态，分为提出和通过
        VersionStatus status;
    }
    enum VersionStatus{Init,Pass}
    mapping(uint=>Version) versionMap; 

    //添加版本，传入元素版本数组、消息版本数组，开始事件
    function addVersion(uint[] _elementVersion,uint[] _messageVersion,uint _start) public{
        //校验传入参数
        require(_elementVersion.length<=count&&_messageVersion.length<=messageCount,"传入的参数有误");
        //版本号
        uint ver=++versionNum;
        //初始化版本结构
        versionMap[ver]=Version(ver,_elementVersion,_messageVersion,_start,VersionStatus.Init);
        //versionMap[ver]=v;
        //调用投票合约的新增版本发布提案函数
        vote.addProposal(this, ver);     
    }

    function passVersion(uint v_id) public {
        //通过提案后修改版本状态为通过
        //Version storage v=versionMap[v_id];
        require(versionMap[v_id].status==VersionStatus.Init,"只有处于发起状态的版本可以通过");
        //v.status=VersionStatus.Pass;
        versionMap[v_id].status=VersionStatus.Pass;
    }

    //版本id  返回版本号、元素版本数组、消息版本数组、开始事件
    function getVersion(uint verId) public view returns(uint,uint[],uint[],uint,VersionStatus){
        require(verId<=versionNum,"不存在该版本");
        //Version storage v=versionMap[verId];
        return (versionMap[verId].id,versionMap[verId].elementVersion,versionMap[verId].messageVersion,versionMap[verId].start,versionMap[verId].status);
    }

     /* ------------------------------------------------------------------------------------------------ */
     uint instanceCount=0;
     mapping(uint=>Instance) instanceMap;
     enum InstanceStatus{
        Running,Finish
     }
     struct Instance{
         //实例id
         uint id;
         //实例所属的版本
         uint versionId;
         //实例状态
         InstanceStatus instanceStatus;
         //映射到该版本的元素的数据信息
         mapping(uint=>InstanceElement) instanceElementMap;
         //映射到该版本的消息的数据信息
         mapping(uint=>InstanceMessage) instanceMesMap;
         //存储全局变量
         GlobalValue globalValue;    
     }
    struct GlobalValue{
        mapping(string=>string) stringValueMap;
        mapping(string=>uint) intValueMap;
        mapping(string=>bool) boolValueMap;
    }
    struct InstanceElement{
        //元素id
        uint id;
        //执行次数，可以执行多次
        uint count;
        //实例状态
        ElementStatus elementStatus;
    }
    enum ElementStatus{
         Waiting,Enabled,Completed
     }
    //实例消息状态，发送、接收、拒绝(拒绝的消息可以进行重发)
    enum InstanceMessageStatus{
        Send,Receive,Reject
    }
    struct InstanceMessage{
        //消息id
        uint messageId;
        //次数
        uint count;
        //消息的内容
        mapping(uint=>InstanceMessageContent) instanceMessageContentMap;
    }

    struct InstanceMessageContent{
        //本次发送时消息的版本号
        uint version;
        //消息状态
        InstanceMessageStatus instanceMessageStatus;
        //消息的发送者
        address sender;
        //消息的接受者
        address receiver;
        //消息的内容
        string content;
    }

    function getInstanceBool(uint _id,string _name) public view returns(bool){
        return instanceMap[_id].globalValue.boolValueMap[_name];
    }
    function getInstanceInt(uint _id,string _name) public view returns(uint){
        return instanceMap[_id].globalValue.intValueMap[_name];
    }
    function getInstanceString(uint _id,string _name) public view returns(string){
        return instanceMap[_id].globalValue.stringValueMap[_name];
    }
    //查询实例数据，返回实例的版本号、实例的状态
    function getInstance(uint _id) public view returns(uint,InstanceStatus){
        require(_id<=instanceCount,"不存在相应的实例");
        //Instance memory i=instanceMap[_id];
        //返回实例所属的版本号 实例的状态 实例的元素数组组成
        return (instanceMap[_id].versionId,instanceMap[_id].instanceStatus);
    }

    //查询实例的元素信息，返回实例中元素的执行次数和元素的状态
    function getInstanceElement(uint _id,uint e_id) public view returns(uint,ElementStatus){
        require(_id<=instanceCount&&instanceMap[_id].instanceElementMap[e_id].id!=0,"不存在实例或者元素");
        return (instanceMap[_id].instanceElementMap[e_id].count,instanceMap[_id].instanceElementMap[e_id].elementStatus);
    }

    //查询实例的消息信息，传入实例id、消息id、消息的次数，返回消息的版本号、消息的状态、消息的发送者、消息的接收者、消息的内容
    function getInstanceMes(uint _id,uint m_id,uint _count) public view returns(uint,InstanceMessageStatus,address,address,string){
        require(_id<=instanceCount&&instanceMap[_id].instanceMesMap[m_id].messageId!=0&&instanceMap[_id].instanceMesMap[m_id].count>=_count,"不存在实例或不存在消息");
        //InstanceMessageContent storage imc=instanceMap[_id].instanceMesMap[m_id].instanceMessageContentMap[_count];
        return (instanceMap[_id].instanceMesMap[m_id].instanceMessageContentMap[_count].version,instanceMap[_id].instanceMesMap[m_id].instanceMessageContentMap[_count].instanceMessageStatus,instanceMap[_id].instanceMesMap[m_id].instanceMessageContentMap[_count].sender,instanceMap[_id].instanceMesMap[m_id].instanceMessageContentMap[_count].receiver,instanceMap[_id].instanceMesMap[m_id].instanceMessageContentMap[_count].content);
    }

    //创建实例
    function newInstance(uint v_id) public{
        require(v_id<=versionNum&&versionMap[v_id].status==VersionStatus.Pass,"版本号不存在或者版本未通过投票");
        //新的实例id
        uint i_id=++instanceCount;
        uint start=versionMap[v_id].start;
        Instance storage i=instanceMap[i_id];
        i.id=i_id;
        i.versionId=v_id;
        i.instanceStatus=InstanceStatus.Running;
        /* uint i_id=++instanceCount;
        Version storage v=versionMap[v_id];
        uint[] storage eIds=v.elementVersion;
        //开始事件
        uint start=v.start;
        Instance storage i=instanceMap[i_id];
        i.id=i_id;
        i.versionId=v_id;
        i.instanceStatus=InstanceStatus.Running;
        //初始化当前版本绑定的实例id
        for(uint j=0;j<eIds.length;j++){
            if(eIds[j]!=0){
                InstanceElement storage ie=i.instanceElementMap[j+1];
                ie.id=j+1;
                ie.count=0;
                //开始事件默认置未可执行状态
                if(elementMap[j].versionMap[eIds[j]].elementType==ElementType.Start){
                    ie.elementStatus=ElementStatus.Enabled;
                }else{
                    ie.elementStatus=ElementStatus.Waiting;
                }
                i.instanceElementMap[j]=ie;
            }
        } */
        //完成开始任务
        i.instanceElementMap[start]=InstanceElement(start,0,ElementStatus.Enabled);
        completeTask(i_id, start);
    }

    

    function completeTask(uint i_id,uint e_id) public {
        require((instanceMap[i_id].instanceStatus==InstanceStatus.Running)&&(instanceMap[i_id].instanceElementMap[e_id].elementStatus==ElementStatus.Enabled),"该实例已完成或该元素不处于可执行状态");
        require(canExecution(i_id,e_id),"该任务不满足执行条件");
        Instance storage i=instanceMap[i_id];
        //Version storage v=versionMap[i.versionId];
        uint versionId=versionMap[i.versionId].elementVersion[e_id-1];
        ElementStruct storage es=elementMap[e_id].versionMap[versionId];
        //elementMap[e_id].versionMap[versionMap[i.versionId].elementVersion[e_id-1]]
        InstanceElement storage ie=i.instanceElementMap[e_id];
        ie.count++;
        uint[] memory next=es.nextElements;
        finishTask(i_id,e_id);
        for(uint j=0;j<next.length;j++){
            //如果为当前元素类型为编排任务或者开始事件，直接启用下一元素
            if(es.elementType==ElementType.ChoreographyTask||es.elementType==ElementType.Start){
                enableTask(i_id,next[j]);
            }else if(es.elementType==ElementType.Exclusive){
                //排他分离网关
                if(next.length>1){
                    Decision memory d=decisionMap[elementMap[next[j]].versionMap[versionMap[i.versionId].elementVersion[next[j]-1]].decisionId];
                    if(evaluateDecision(d,i_id)){
                        enableTask(i_id,next[j]);
                        break;
                    }
                }else{
                //排他合并网关    
                    enableTask(i_id,next[j]);
                }
            }else if(es.elementType==ElementType.Parallel||es.elementType==ElementType.EventBased){
                enableTask(i_id,next[j]);
            }
        }
        emit finishTask(i_id,e_id);
    }


    /* function changeTaskStatus(uint i_id,uint e_id,ElementStatus elementStatus) internal {
        if(elementMap[e_id].versionMap[ versionMap[instanceMap[i_id].versionId].elementVersion[e_id-1]].elementType==ElementType.End&&elementStatus==ElementStatus.Enabled){
            instanceMap[i_id].instanceStatus=InstanceStatus.Finish;
        }
        if(instanceMap[i_id].instanceElementMap[e_id].id==0){
            instanceMap[i_id].instanceElementMap[e_id]=InstanceElement(e_id,0,elementStatus);
        }else{
            instanceMap[i_id].instanceElementMap[e_id].elementStatus=elementStatus;
        }
    } */

    function enableTask(uint i_id,uint e_id) internal{
        bool tmp=true;
        Instance storage i=instanceMap[i_id];
        ElementStruct storage es=elementMap[e_id].versionMap[versionMap[i.versionId].elementVersion[e_id-1]];
        uint[] memory pre=es.preElements;
        for(uint j=0;j<pre.length;j++){
             if(es.elementType==ElementType.Parallel){
                 if(i.instanceElementMap[pre[j]].elementStatus!=ElementStatus.Completed){
                     tmp=false;
                     break;
                 }
             }else{
                 if(i.instanceElementMap[pre[j]].elementStatus!=ElementStatus.Completed) break;
             }
        }
       // require(tmp,"不满足启用状态");
        if(tmp){
            if(instanceMap[i_id].instanceElementMap[e_id].id==0){
                instanceMap[i_id].instanceElementMap[e_id]=InstanceElement(e_id,0,ElementStatus.Enabled);
            }else{
                instanceMap[i_id].instanceElementMap[e_id].elementStatus=ElementStatus.Enabled;
            }
        }
    }

    function finishTask(uint i_id,uint e_id) internal{
        if(elementMap[e_id].versionMap[ versionMap[instanceMap[i_id].versionId].elementVersion[e_id-1]].elementType==ElementType.End){
            instanceMap[i_id].instanceStatus=InstanceStatus.Finish;
        }
        instanceMap[i_id].instanceElementMap[e_id].elementStatus=ElementStatus.Completed;
    }
    function waitTask(uint i_id,uint e_id) internal{
        instanceMap[i_id].instanceElementMap[e_id].elementStatus=ElementStatus.Waiting;
    }


    function canExecution(uint i_id,uint e_id) public view returns(bool){
        //根据实例id获取实例
        Instance storage i=instanceMap[i_id];
        //根据实例创建时绑定的版本号 获取该实例对应的版本信息
        Version storage v=versionMap[i.versionId];
        //获取实例中对应的元素的信息
        ElementStruct storage es=elementMap[e_id].versionMap[v.elementVersion[e_id-1]];
        //获取对应实例中该元素当前执行次数
        uint countNow=i.instanceElementMap[e_id].count;
        //如果编排任务的状态不处于可执行的状态时 直接返回false
        //require(i.instanceElementMap[e_id].elementStatus==ElementStatus.Enabled,"任务不处于可执行状态");
        if(i.instanceElementMap[e_id].elementStatus!=ElementStatus.Enabled){
            return false;
        }
        if(es.elementType==ElementType.ChoreographyTask){
             string[] storage participant=es.participant;
             bool tmp=false;
             for(uint k=0;k<participant.length;k++){
                if(acl.judgeParticipantRole(this,msg.sender,participant[k])){
                        tmp=true;
                        break;
                }
             }
             //require(tmp,"用户不属于该编排任务的参与者");
              //没有该任务的执行权
            if(!tmp) return false;
        }
        //获取实例中对应的消息信息
        uint[] storage message=es.messages;
        //判断消息的状态
        for(uint j=0;j<message.length;j++){
            //如果任务的执行次数countNow和消息的执行次数一样 或者大于时说明执行条件一定未满足，返回false 无法执行 
            //require(i.instanceMesMap[message[j]].count>countNow,"条件未满足");
            if(i.instanceMesMap[message[j]].count<=countNow){
                return false;
            }
            //require(i.instanceMesMap[message[j]].instanceMessageContentMap[countNow+1].instanceMessageStatus==InstanceMessageStatus.Receive,"存在消息不处于已接收状态");
            //如果有任何消息的状态不处于已接收状态 则返回false 刚刚发出或者已经被拒绝要重发
            if(i.instanceMesMap[message[j]].instanceMessageContentMap[countNow+1].instanceMessageStatus!=InstanceMessageStatus.Receive){
                return false;
            }
        }
        return true;
    }

    

    function sendMessage(uint i_id,uint m_id,string _content,address _receiver,string[] _valName,string[] _valValue) public{
        require(canSendMessage(i_id,m_id,_receiver,_valName),"未满足发送消息的条件");
        Instance storage i=instanceMap[i_id];
        //分情况 之前没发过的情况下 要初始化    如果之前发过  再分情况 1当前的编排任务新增消息  2重新发送被拒绝的消息(校验消息是否为被拒绝的状态)
        uint mv_id=versionMap[i.versionId].messageVersion[m_id-1];
        uint e_id=messageMap[m_id].versionMap[versionMap[i.versionId].messageVersion[m_id-1]].task;
        InstanceMessage storage im=i.instanceMesMap[m_id];
        if(im.messageId==0){
            im.count=1;
            im.messageId=m_id;
        }else if(im.count==i.instanceElementMap[e_id].count){
                im.count++;
        }
        im.instanceMessageContentMap[im.count]=InstanceMessageContent(mv_id,InstanceMessageStatus.Send,msg.sender,_receiver,_content);
        addInstanceData(i,messageMap[m_id].versionMap[mv_id],_valName,_valValue);
        if(messageMap[m_id].versionMap[versionMap[i.versionId].messageVersion[m_id-1]].messageType==MessageType.Request){
            denyInstanceElement(i_id,elementMap[e_id].versionMap[versionMap[i.versionId].elementVersion[e_id-1]].exclusiveIds);
        }
        emit sendMes(i_id,m_id,_receiver);
        
    }

    function denyInstanceElement(uint i_id,uint[] denyIds) internal{
        for(uint i=0;i<denyIds.length;i++){
            waitTask(i_id,denyIds[i]);
        }
    }


    function addInstanceData(Instance storage i,MessageStruct storage ms,string[] _valName,string[] _valValue) internal{
        for(uint j=0;j<_valName.length;j++){
            if(Common.stringEqual(ms.valTypeMap[_valName[j]],"string")){
                i.globalValue.stringValueMap[_valName[j]]=_valValue[j];
            }else if(Common.stringEqual(ms.valTypeMap[_valName[j]],"int")){
                i.globalValue.intValueMap[_valName[j]]=Common.parseInt(_valValue[j],0);
            }else if(Common.stringEqual(ms.valTypeMap[_valName[j]],"bool")){
                if(Common.parseInt(_valValue[j],0)==0){
                    i.globalValue.boolValueMap[_valName[j]]=false;
                }else{
                    i.globalValue.boolValueMap[_valName[j]]=true;
                }
            }
        }
    }

    function canSendMessage(uint i_id,uint m_id,address _receiver,string[] _valName) public view returns(bool){
        Instance storage i=instanceMap[i_id];
        //uint versionId=versionMap[i.versionId].messageVersion[m_id-1];
        MessageStruct storage ms=messageMap[m_id].versionMap[versionMap[i.versionId].messageVersion[m_id-1]];
        uint e_id=ms.task;
        //消息绑定的元素必须处于可执行状态
        //require(i.instanceElementMap[e_id].elementStatus==ElementStatus.Enabled,"编排任务当前不可执行");
        if(i.instanceElementMap[e_id].elementStatus!=ElementStatus.Enabled){
            return false;
        }
        //消息的接收者和发送者必须拥有相应消息的角色
        //require(acl.judgeParticipantRole(this,msg.sender,ms.sender)&&acl.judgeParticipantRole(this,_receiver,ms.receiver),"消息发送者或者接收者不满足角色条件");
        if(!acl.judgeParticipantRole(this,msg.sender,ms.sender)||!acl.judgeParticipantRole(this,_receiver,ms.receiver)){
            return false;
        }
        InstanceMessage storage im=i.instanceMesMap[m_id];
        uint[] storage messages=elementMap[e_id].versionMap[versionMap[i.versionId].elementVersion[e_id-1]].messages;
        uint countNow=i.instanceElementMap[e_id].count;
        //require(!(im.count==(countNow+1)&&im.instanceMessageContentMap[im.count].instanceMessageStatus!=InstanceMessageStatus.Reject),"消息不处于被拒绝状态，无法重发");
        if(im.count==(countNow+1)&&im.instanceMessageContentMap[im.count].instanceMessageStatus!=InstanceMessageStatus.Reject){
            return false;
        }
        if(ms.messageType==MessageType.Reply){
            for(uint j=0;j<messages.length;j++){
                if(messageMap[messages[j]].versionMap[versionMap[i.versionId].messageVersion[messages[j]-1]].messageType==MessageType.Request){
                    if(i.instanceMesMap[messages[j]].count<=countNow) return false;
                    require(i.instanceMesMap[messages[j]].instanceMessageContentMap[countNow+1].instanceMessageStatus==InstanceMessageStatus.Receive,"消息不处于已接受状态");
                    if(i.instanceMesMap[messages[j]].instanceMessageContentMap[countNow+1].instanceMessageStatus!=InstanceMessageStatus.Receive) return false;
                }
            }
        }
        if(_valName.length!=ms.valName.length) return false;
        for(uint k=0;k<ms.valName.length;k++){
            if(!Common.stringEqual(_valName[k],ms.valName[k])) return false;
        }
        return true;
    }

    function ackMessage(uint i_id,uint m_id,InstanceMessageStatus status) public{
        require(status!=InstanceMessageStatus.Send,"回复内容必须是接收或者拒绝");
        Instance storage i=instanceMap[i_id];
        Version storage v=versionMap[i.versionId];
        uint versionId=v.messageVersion[m_id-1];
        MessageStruct storage ms=messageMap[m_id].versionMap[versionId];
        require(acl.judgeParticipantRole(this,msg.sender,ms.receiver),"确认者没有该消息的确认角色");
        require(i.instanceElementMap[ms.task].elementStatus==ElementStatus.Enabled,"编排任务不处于可执行的状态");
        uint countNow=i.instanceElementMap[ms.task].count+1;
        require(i.instanceMesMap[m_id].instanceMessageContentMap[countNow].instanceMessageStatus==InstanceMessageStatus.Send,"只有处于发送状态的消息可以由接收者确认或者拒绝");
        require(i.instanceMesMap[m_id].instanceMessageContentMap[countNow].receiver==msg.sender,"消息确认者不是该消息的接收者");
        InstanceMessageContent storage ims=i.instanceMesMap[m_id].instanceMessageContentMap[countNow];
        ims.instanceMessageStatus=status; 
        if(status==InstanceMessageStatus.Receive&&canExecution(i_id, ms.task)){
            completeTask(i_id, ms.task);
        }
    }


    function evaluateDecision(Decision _decision,uint  i_id) public view returns (bool){
        Instance storage i=instanceMap[i_id];
        if(_decision.decisionType == DecisionType.StringTyp){
            return Common.evaluate(i.globalValue.stringValueMap[_decision.variableName],_decision.operator, _decision.stringCondition);
        }
        else if(_decision.decisionType == DecisionType.IntTyp){
            return Common.evaluate(i.globalValue.intValueMap[_decision.variableName], _decision.operator, _decision.intCondition);
        }else if(_decision.decisionType == DecisionType.BoolTyp){
            return Common.evaluate(i.globalValue.boolValueMap[_decision.variableName], _decision.operator);
        }
    }  

}