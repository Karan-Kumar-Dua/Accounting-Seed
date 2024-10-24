import { LightningElement, wire, api, track } from 'lwc';
import {LabelService, NotificationService,Constants } from 'c/utils';
import Labels from './labels';
import { keywords } from 'c/lookupKeywords';
import { CashReceipt,GlAccount } from 'c/sobject';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import getVoidDetails from '@salesforce/apex/CashReceiptVoidHelper.getVoidDetails';
import { getRecord, getFieldDisplayValue,getFieldValue } from "lightning/uiRecordApi";
import voidCashReceipt from '@salesforce/apex/CashReceiptVoidHelper.voidCashReceipt';


const cashReceipt = CashReceipt;
const cashReceiptFields = [
    `${cashReceipt.objectApiName}.${cashReceipt.cash_receipt_name.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.cash_flow_category_name.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.cash_flow_category.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.receipt_date.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.account_r_name.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.account.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.check_number.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.amount.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.void_description.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.payment_processor_type.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.payment_reference.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.payment_processor_name.fieldApiName}`
];
export default class CashReceiptVoid extends LightningElement {
    @api recordId;
    @track defaultDate = new Date().toISOString().split('T')[0]; 

    labels = {...Labels, ...LabelService};
    receiptDateInfo;
    voidDescriptionInfo;
    amountInfo;
    cashFlowCategoryInfo;
    customerInfo;
    checkNumberInfo;
    wiredGetRecordData;
    spinnerClass = 'slds-show';
    isLoaded=false;
    fields=cashReceiptFields;
    voidDetails;
    selectedCashFlowCategory;
    isProcessing = false;

    //search filter for cash flow category
    glFilter = {
        type: keywords.type.STRING,
        field: GlAccount.type.fieldApiName,
        op: keywords.op.EQUAL,
        val: Constants.GL_ACCT.TYPE_CASH_FLOW
    };

    //get current object info to fetch helptext, labels and api names for the fields
    @wire(getObjectInfo, { objectApiName: CashReceipt.objectApiName })
    cashReceiptObjectInfo;

    //get current record to display on the void page
    @wire(getRecord, { recordId: "$recordId",fields: '$fields' })
    wiredAccount({ error, data }) {
        if (data) {
            this.wiredGetRecordData = data;
            this.arrangeTheValues();
            this.spinnerClass = 'slds-hide';
            this.isLoaded = true;
        } else if (error) {
            NotificationService.displayToastMessage(
                this,
                error.body.message,
                `${LabelService.commonToastErrorTitle}:`,
                'error'
            );
            this.spinnerClass = 'slds-hide';
            this.isLoaded = true;
        }
    }
   
    //get cr void data from apex
    @wire(getVoidDetails, {})
    wiredVoidDetails({ error, data }) {
        this.spinnerClass = 'slds-show';
        if (data) {
            this.voidDetails =  JSON.parse(JSON.stringify(data));
            this.spinnerClass = 'slds-hide';
        } else if (error) {
            NotificationService.displayToastMessage(
                this,
                error.body.message,
                `${LabelService.commonToastErrorTitle}:`,
                'error'
            );
            this.spinnerClass = 'slds-hide';
        }else{
            this.spinnerClass = 'slds-hide';
        }
    }
    //fetch all the field infos with label, apiName, helptext and reference objects
    arrangeTheValues() {
        this.receiptDateInfo = this.getCashReceiptFieldInfo(cashReceipt.receipt_date.fieldApiName);
        this.voidDescriptionInfo = this.getCashReceiptFieldInfo(cashReceipt.void_description.fieldApiName);
        this.amountInfo = this.getCashReceiptFieldInfo(cashReceipt.amount.fieldApiName);
        this.cashFlowCategoryInfo = this.getCashReceiptFieldInfo(cashReceipt.cash_flow_category.fieldApiName);
        this.customerInfo = this.getCashReceiptFieldInfo(cashReceipt.account.fieldApiName);
        this.checkNumberInfo = this.getCashReceiptFieldInfo(cashReceipt.check_number.fieldApiName);
    }

    //to get appropriate field info 
    getCashReceiptFieldInfo = (fieldName) => {
        if (this.cashReceiptObjectInfo?.data?.fields[fieldName]) {
            return {
                label: this.cashReceiptObjectInfo.data.fields[fieldName] ? this.cashReceiptObjectInfo.data.fields[fieldName]?.label : '',
                helpText: this.cashReceiptObjectInfo.data.fields[fieldName] ? this.cashReceiptObjectInfo.data.fields[fieldName]?.inlineHelpText : '',
                apiName: fieldName,
                referenceObject: this.cashReceiptObjectInfo.data.fields[fieldName]?.referenceToInfos.length > 0 ? 
                    this.cashReceiptObjectInfo.data.fields[fieldName]?.referenceToInfos[0].apiName : ''
            }
        }
        return undefined
    }
    //this will close the modal
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    
    get receiptDate(){
        return this.wiredGetRecordData && getFieldDisplayValue(this.wiredGetRecordData,cashReceipt.receipt_date);
    }
    get amount(){
        return this.wiredGetRecordData && getFieldDisplayValue(this.wiredGetRecordData,cashReceipt.amount);
    }
    get customerName(){
        return this.wiredGetRecordData && getFieldValue(this.wiredGetRecordData,cashReceipt.account_r_name);
    }
    get checkNumber(){
        return this.wiredGetRecordData && getFieldValue(this.wiredGetRecordData,cashReceipt.check_number);
    }
    get cashFlowCategoryName(){
        return this.wiredGetRecordData && getFieldValue(this.wiredGetRecordData,cashReceipt.cash_flow_category_name);
    }
    get hasCheckNumber(){
        return this.wiredGetRecordData && this.checkNumber ? true : false;
    }
    get isCashFlowStatementEnabled(){
        return this.voidDetails && this.voidDetails.isCashFlowStatementEnabled === true ? true : false;
    }
    get hasCashFlowStatementEnabledWhenNoCheckNumber(){
        return this.isCashFlowStatementEnabled && !this.hasCheckNumber ? true : false;
    }
    get hasCashFlowStatementEnabledWhenCheckNumber(){
        return this.isCashFlowStatementEnabled && this.hasCheckNumber ? true : false;
    }
    get hasCashFlowCategorySelected(){
        return this.wiredGetRecordData && this.cashFlowCategoryName ? false : true;
    }
    get infoMessage(){
        return this.wiredGetRecordData && this.voidDetails && 
                getFieldDisplayValue(this.wiredGetRecordData,cashReceipt.payment_processor_type) === 'Cardknox' ? 
                this.labels.INF_CARDKNOX_VOID_UI_MESSAGE.replaceAll('{0}',getFieldValue(this.wiredGetRecordData,cashReceipt.cash_receipt_name)).replaceAll('{1}', getFieldValue(this.wiredGetRecordData,cashReceipt.payment_processor_name)).replace('{2}', getFieldValue(this.wiredGetRecordData,cashReceipt.payment_reference)) : 
                getFieldDisplayValue(this.wiredGetRecordData,cashReceipt.payment_processor_type) === 'Stripe' ?
                this.labels.INF_STRIPE_VOID_UI_MESSAGE.replaceAll('{0}',getFieldValue(this.wiredGetRecordData,cashReceipt.cash_receipt_name)).replaceAll('{1}', getFieldValue(this.wiredGetRecordData,cashReceipt.payment_processor_name)).replace('{2}', getFieldValue(this.wiredGetRecordData,cashReceipt.payment_reference)) : 
                '';
    }
    handleDateChange(evt){
        this.defaultDate = evt.detail.value;
    }
    handleValueChange(evt){
        this.selectedCashFlowCategory = evt.detail.value;
    }
    handleVoidClick(){
        this.spinnerClass = 'slds-show';
        this.isProcessing = true;
        let voidData = {cashReceiptId: this.recordId,voidReceiptDate : this.defaultDate, 
                        description : this.refs.voidDescription.value,
                        cashFlowCategory : this.selectedCashFlowCategory,
                        paymentId : getFieldValue(this.wiredGetRecordData,cashReceipt.payment_reference)};
        
        voidCashReceipt({jsonReq : JSON.stringify(voidData)})
            .then(data => {
                NotificationService.displayToastMessage(
                    this,
                    this.labels.INF_THE_CASH_RECEIPT_WAS_VOIDED,
                    `${LabelService.commonToastSuccessTitle}:`,
                    'success'
                );
                this.handleCancel();
            })
            .catch(error => {
                NotificationService.displayToastMessage(
                    this,
                    error.body.message,
                    `${LabelService.commonToastErrorTitle}:`,
                    'error'
                );
            })
            .finally(() => {
                this.spinnerClass = 'slds-hide';
                this.isProcessing = false;
            })
    }
}