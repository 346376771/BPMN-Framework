pragma solidity ^0.4.22;
pragma experimental ABIEncoderV2;


library Common{
    
    function evaluate(string memory _firststring,Choreography.Operator _op,string memory _secondstring) public pure returns (bool){
        if(_op == Choreography.Operator.EQUAL){
            // Required way to string compare
            if(keccak256(abi.encodePacked(_firststring)) == keccak256(abi.encodePacked(_secondstring))){
                return true;
            }
            else return false;
        }
        else if(_op != Choreography.Operator.NEQ){
            if(keccak256(abi.encodePacked(_firststring)) != keccak256(abi.encodePacked(_secondstring))){
                return true;
            }
            else return false;
        }
        else return false;
    }

    function evaluate(bool _boolValue,Choreography.Operator _op) public pure returns (bool){
        if(_op == Choreography.Operator.True){
           if(_boolValue)return true;
           else return false;
           
        }
        else if(_op == Choreography.Operator.False){
            if(!_boolValue)return true;
            else return false;
        }
        else return false;
    }


    // Evaluates a decision based on int
    function evaluate(uint _firstint, Choreography.Operator _op, uint[] memory _secondint)
        public pure returns(bool status){
        // a < b
        if(_op == Choreography.Operator.LESS){

            if(_firstint < _secondint[0]){
                return true;
            }
            else return false;
        }

        // a > b
        if(_op == Choreography.Operator.GREATER){

            if(_firstint > _secondint[0]){
                return true;
            }
            else return false;
        }

        // a = b
        if(_op == Choreography.Operator.EQUAL){

            if(_firstint == _secondint[0]){
                return true;
            }
            else return false;
        }

        // a <= b
        if(_op == Choreography.Operator.LEQ){
            if(_firstint <= _secondint[0]){
                return true;
            }
            else return false;
        }

        // a >= b
        if(_op == Choreography.Operator.GEQ){

            if(_firstint >= _secondint[0]){
                return true;
            }
            else return false;
        }
        
        if(_op == Choreography.Operator.ELEMENT){
            for (uint elementid = 0; elementid < _secondint.length ; elementid++){
                if (_firstint == _secondint[elementid]){
                    return true;
                }
            }           
        }
        return false;
    }



    function stringEqual(string valueOne,string valueTwo) public pure returns(bool){
        if(keccak256(abi.encodePacked(valueOne)) == keccak256(abi.encodePacked(valueTwo))){
            return true;
        }else return false;
    }


     function parseInt(string memory _a, uint _b) public pure returns (uint _parsedInt) {
        bytes memory bresult = bytes(_a);
        uint mint = 0;
        bool decimals = false;
        for (uint i = 0; i < bresult.length; i++) {
            if ((uint(uint8(bresult[i])) >= 48) && (uint(uint8(bresult[i])) <= 57)) {
                if (decimals) {
                    if (_b == 0) {
                        break;
                    } else {
                     _b--;
                    }
                }           
                mint *= 10;
                mint += uint(uint8(bresult[i])) - 48;
            } else if (uint(uint8(bresult[i])) == 46) {
                decimals = true;
            }
        }
        if (_b > 0) {
            mint *= 10 ** _b;
        }
        return mint;
    }
    
}