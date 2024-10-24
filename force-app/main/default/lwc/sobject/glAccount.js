import GL_ACCOUNT from "@salesforce/schema/GL_Account__c";
import TYPE from "@salesforce/schema/GL_Account__c.Type__c";
import BANK from "@salesforce/schema/GL_Account__c.Bank__c";
import NAME_FIELD from '@salesforce/schema/GL_Account__c.Name';
import { CommonUtils } from "c/utils";

export default class GlAccount {
    static packageQualifier = CommonUtils.getPackageQualifier(GL_ACCOUNT.objectApiName);
    packageQualifier = CommonUtils.getPackageQualifier(GL_ACCOUNT.objectApiName);
    static objectApiName = GL_ACCOUNT.objectApiName;
    static gl_account = GL_ACCOUNT;
    
    static nameField = NAME_FIELD;
    static type = TYPE;
    static bank = BANK;
}