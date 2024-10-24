// imported for PQ reason
import CD_AMOUNT from '@salesforce/schema/Cash_Disbursement__c.Amount__c';

// temp fix for Platform event API name imported in LWC uses “c” instead of “e” as suffix
const RECORD_ID = {fieldApiName: "Request_Id__c", objectApiName: "AS_Immediate_Event__e"};
const TYPE1 = {fieldApiName: "Type__c", objectApiName: "AS_Immediate_Event__e"}

import { CommonUtils } from 'c/utils';

export default class ASImmediateEvent {

  static packageQualifier = CommonUtils.getPackageQualifier(CD_AMOUNT.fieldApiName);
  packageQualifier = CommonUtils.getPackageQualifier(CD_AMOUNT.fieldApiName);

  static record_id = CommonUtils.getObjectWithQualifier(RECORD_ID, CommonUtils.getPackageQualifier(CD_AMOUNT.fieldApiName));
  static type = CommonUtils.getObjectWithQualifier(TYPE1, CommonUtils.getPackageQualifier(CD_AMOUNT.fieldApiName));
  
  record_id = CommonUtils.getObjectWithQualifier(RECORD_ID, CommonUtils.getPackageQualifier(CD_AMOUNT.fieldApiName)).fieldApiName;
  type = CommonUtils.getObjectWithQualifier(TYPE1, CommonUtils.getPackageQualifier(CD_AMOUNT.fieldApiName)).fieldApiName;

}