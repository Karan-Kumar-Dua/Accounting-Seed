import { api, wire, track } from 'lwc';
import { LabelService,KnowledgeBase,NavigationService } from 'c/utils';
import { getRecord } from 'lightning/uiRecordApi';
import { getPicklistValues,getObjectInfo } from 'lightning/uiObjectInfoApi';
import TYPE_F from '@salesforce/schema/Cash_Receipt__c.Payment_Type__c';
import CR_OBJECT from '@salesforce/schema/Cash_Receipt__c';
import getWrappedBillings from '@salesforce/apex/BillingPaymentReceiveHelper.getWrappedBillings';
import getPaymentProcessors from '@salesforce/apex/BillingPaymentReceiveHelper.getPaymentProcessors';
import receivePayment from '@salesforce/apex/BillingPaymentReceiveHelper.receivePayment';
import { labels } from './labels';
import { PaymentProcessor, PaymentMethod } from "c/sobject";

const TEST_MODE_WARNING_MESSAGE = {
    message: LabelService.testModeWarningMessage
}

// picklist values, do not swap for custom labels
const CARDKNOX_TYPE = 'Cardknox';
const ELECTRONIC = 'Electronic';
const CHECK = 'Check';
const CC_FLAT_FEE = 'CC Flat Fee';
const CC_PERCENT = 'CC Percent';
const ACH_FLAT_FEE = 'ACH Flat Fee';
const ACH_PERCENT = 'ACH Percent';
const NONE = 'None';

export default class BillingReceivePayment extends NavigationService {
    @api recordId;
    @track wrappedBilling;
    @track paymentInfo = [];
    @track warningMessages = [];
    @track errors = [];
    keyIsValid = false;
    receivePaymentData = {};
    labels = { ...labels, ...LabelService };
    showSpinner = true;
    knowledgeBase = [
    { 
        iconName: 'standard:question_feed', 
        iconAltText: LabelService.KNOWLEDGE_BASE,
        url: KnowledgeBase.recievePayment
    }];
    
    @wire(getRecord, { recordId: '$recordId', layoutTypes: ['Full'], modes: ['View'] })
    billing;

    @wire(getPaymentProcessors, { customerId : "$billing.data.fields.AcctSeed__Customer__c.value"})
    paymentProcessor({data,error}) {
        if (data) {
            if (data.noDataAvailable === true) {
                this.paymentInfo['ignoreElectronic'] = true;
                data.errorMessage === this.labels.invalidXKey ? this.errors.push(data.errorMessage) : '';
                this.keyIsValid = data.errorMessage === this.labels.invalidXKey ? false : true;
                this.paymentInfo['selectedPaymentType'] = CHECK;
            } else {
                this.keyIsValid = true;
                this.paymentInfo['selectedPaymentType'] = ELECTRONIC;
                this.paymentInfo['ignoreElectronic'] = false;
                this.paymentInfo['paymentDetails'] = JSON.parse(JSON.stringify(data));
                this.prepareTestModeWarningMessage(this.paymentInfo.paymentDetails.selectedPPId);
            }
            this.fetchBillings();

        }else if (error) {
            this.errors.push(error.body.message); 
        }
        this.showSpinner = false;
    }

    @wire(getObjectInfo, { objectApiName: CR_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: "$objectInfo.data.defaultRecordTypeId",
        fieldApiName: TYPE_F
    })
    typePicklistValues({ data, error }) {
        if (data) {
            this.paymentInfo['paymentTypes'] = data.values;
        } else if (error) {
            this.errors.push(error.body.message); 
        }
    };
    fetchBillings(){
        getWrappedBillings({ billingId: this.recordId})
                .then((result) => {
                    this.wrappedBilling = JSON.parse(JSON.stringify(result));
                    this.wrappedBilling.cashReceipt['inEditMode'] = true;
                    this.wrappedBilling.cashReceipt['singleUseRow'] = true;
                    this.wrappedBilling.billTotalAmount = parseFloat(this.wrappedBilling.billTotalBalance) - parseFloat(this.wrappedBilling.billCrAdjustment);
                    this.handleCnvFeeCalculation();
                }).catch((error)=>{
                    this.errors.push(error.body.message); 
                })
    }
    get availablePaymentMethods() {
        if (!this.paymentInfo || !this.paymentInfo.paymentDetails || !this.paymentInfo.paymentDetails.paymentMethodsWithProcessor
            || !this.paymentInfo.paymentDetails.paymentMethodsWithProcessor[this.paymentInfo.paymentDetails.selectedPPId]) {
            return [];
        }
        return this.paymentInfo.paymentDetails.paymentMethodsWithProcessor[this.paymentInfo.paymentDetails.selectedPPId];
    }
    get hasErrors() {
        return this.errors.length !== 0 ? true : false;
    }
    handleCancelEvt() {
        this.navigateToViewRecordPage(this.recordId);
    }

    selectedPaymentMethod = () => this.paymentInfo.paymentDetails?.paymentMethods.find(p => p[PaymentMethod.externalId.fieldApiName] === this.paymentInfo.paymentDetails.selectedPMId);
    selectedProcessor = () => this.paymentInfo.paymentDetails?.processorRecords.find(p => p.Id === this.paymentInfo.paymentDetails.selectedPPId);

    handleCnvFeeCalculation(){
        const payMethod = this.selectedPaymentMethod() || {};
        if(payMethod[PaymentMethod.paymentMethodType.fieldApiName] === 'Bank Account'){
            this.handleAchData();
        }else{
            this.handleCcData();
        }
    }
    handleAchData() {
        if (this.paymentInfo.paymentDetails) {
            const processor = this.selectedProcessor();
            let isConFeeValid = false;
            if(processor[PaymentProcessor.achFeeType.fieldApiName] !== NONE){
                if((processor[PaymentProcessor.achFeeType.fieldApiName] === ACH_FLAT_FEE && processor[PaymentProcessor.achFlatFee.fieldApiName])
                || processor[PaymentProcessor.achFeeType.fieldApiName] === ACH_PERCENT && processor[PaymentProcessor.achPercent.fieldApiName]){
                    isConFeeValid = true;
                }
            }
            if(this.paymentInfo.selectedPaymentType === ELECTRONIC && processor[PaymentProcessor.enableConFee.fieldApiName] && processor[PaymentProcessor.type.fieldApiName] === CARDKNOX_TYPE && isConFeeValid){       
                this.wrappedBilling.convenienceFee = processor[PaymentProcessor.achFeeType.fieldApiName] === ACH_FLAT_FEE ?  processor[PaymentProcessor.achFlatFee.fieldApiName] : (parseFloat(this.wrappedBilling.billTotalAmount) * parseFloat(processor[PaymentProcessor.achPercent.fieldApiName]))/100;
                this.wrappedBilling.includeConFee = true;
                this.wrappedBilling.disableIncludeFee = false;
                this.wrappedBilling.totalPaymentAmount = parseFloat(this.wrappedBilling.billTotalAmount) + parseFloat(this.wrappedBilling.convenienceFee);
            }else{
                this.setCheckTypeProperties();
            }
        }else{
            this.setCheckTypeProperties();
        }
    }

    handleCcData(){    
        if(this.paymentInfo.paymentDetails){
            const processor = this.selectedProcessor();
            let isConFeeValid = false;
            if(processor[PaymentProcessor.creditCardFeeType.fieldApiName] !== NONE){
                if((processor[PaymentProcessor.creditCardFeeType.fieldApiName] === CC_FLAT_FEE && processor[PaymentProcessor.ccFlatFee.fieldApiName])
                || processor[PaymentProcessor.creditCardFeeType.fieldApiName] === CC_PERCENT && processor[PaymentProcessor.ccPercent.fieldApiName]){
                    isConFeeValid = true;
                }
            }
            if(this.paymentInfo.selectedPaymentType === ELECTRONIC && processor[PaymentProcessor.enableConFee.fieldApiName] && processor[PaymentProcessor.type.fieldApiName] === CARDKNOX_TYPE && isConFeeValid){       
                this.wrappedBilling.convenienceFee = processor[PaymentProcessor.creditCardFeeType.fieldApiName] === CC_FLAT_FEE ?  processor[PaymentProcessor.ccFlatFee.fieldApiName] : (parseFloat(this.wrappedBilling.billTotalAmount) * parseFloat(processor[PaymentProcessor.ccPercent.fieldApiName]))/100;
                this.wrappedBilling.includeConFee = true;
                this.wrappedBilling.disableIncludeFee = false;
                this.wrappedBilling.totalPaymentAmount = parseFloat(this.wrappedBilling.billTotalAmount) + parseFloat(this.wrappedBilling.convenienceFee);
            }else{
                this.setCheckTypeProperties();
            }
        }else{
            this.setCheckTypeProperties();
        }
    }

    setCheckTypeProperties(){
        this.wrappedBilling.convenienceFee = 0.0;
        this.wrappedBilling.includeConFee = false;
        this.wrappedBilling.disableIncludeFee = true;
        this.wrappedBilling.totalPaymentAmount = parseFloat(this.wrappedBilling.billTotalAmount);
    }

    resetTotalAmount(){
        if(!this.wrappedBilling.includeConFee)
            this.wrappedBilling.totalPaymentAmount = parseFloat(this.wrappedBilling.billTotalAmount);
        else{
            this.handleCnvFeeCalculation();
        }
    }

    handleReceivePayment() {
        this.errors = [];
        this.updateBankAccount();
        const paymentFieldsHolder = this.template.querySelector('c-billing-receive-payment-fields');
        if (paymentFieldsHolder && paymentFieldsHolder.validateFields()) {
            this.receivePaymentData['recordId'] = this.recordId;
            let cashReceiptData = { 'cashReceipt': this.wrappedBilling.cashReceipt };
            this.receivePaymentData = {...this.receivePaymentData, ...paymentFieldsHolder.retrieveValues(), ...cashReceiptData};
            this.showSpinner = true;
            receivePayment({ params: this.receivePaymentData })
                .then((result) => {
                    if (result && result.errors && result.errors.length) {
                        this.errors.push(result.errors[0].message);
                    } else {
                        this.navigateToViewRecordPage(this.recordId);
                    }
                })
                .catch((error) => {
                    this.errors.push(error.body.message);
                })
                .finally(() => {this.showSpinner = false});
        }
    }
    handleValueChange(event) {
        const fieldId = event.detail.fieldId;
        const value = event.detail.value;

        switch (fieldId) {
            case 'discount-amount':
                this.wrappedBilling.billCrAdjustment = value;
                this.wrappedBilling.billTotalAmount = this.wrappedBilling.billTotalBalance - this.wrappedBilling.billCrAdjustment;
                this.resetTotalAmount();
                break;
            case 'payment-processor':
                this.paymentInfo.paymentDetails.selectedPPId = value;
                this.addDefaultPMonPPChange();
                this.prepareTestModeWarningMessage(value);
                this.handleCnvFeeCalculation();
                break;
            case 'payment-type':
                this.paymentInfo.selectedPaymentType = value;
                this.handleCnvFeeCalculation();
                break;
            case 'amount':
                this.wrappedBilling.billTotalAmount = value;
                this.resetTotalAmount();
                break;
            case 'includeConvenienceFees':  
                if(!this.wrappedBilling.disableIncludeFee){
                    this.wrappedBilling.includeConFee = value;
                    this.resetConFee();
                } 
                break;
            case 'payment-methods':
                this.paymentInfo.paymentDetails.selectedPMId = value;
                this.handleCnvFeeCalculation();
                break;
        }
    }

    addDefaultPMonPPChange(){
        let paymentMethods = [];
        Object.keys(this.paymentInfo.paymentDetails.paymentMethodsWithProcessor).every(item => {
            if (item === this.paymentInfo.paymentDetails.selectedPPId) {
                paymentMethods = this.paymentInfo.paymentDetails.paymentMethodsWithProcessor[item];
                this.paymentInfo.paymentDetails.selectedPMId = paymentMethods[0].value;
                return false;
            }       
            return true;       
        });
    }

    resetConFee(){
        if(!this.wrappedBilling.includeConFee){     
            this.wrappedBilling.totalPaymentAmount = parseFloat(this.wrappedBilling.billTotalAmount);
            this.wrappedBilling.convenienceFee = 0.0;
            this.wrappedBilling.feeGlAccount = null;
        }else{
            this.handleCnvFeeCalculation();
        }
    }

    updateBankAccount() {
        const isElectronic = this.paymentInfo.selectedPaymentType === ELECTRONIC;
        if (!isElectronic) {
            return;
        }
        const selectedProcessorId = this.paymentInfo.paymentDetails.selectedPPId;
        const processor = this.paymentInfo.paymentDetails.processorRecords.find(p => p.Id === selectedProcessorId);
        if (processor[PaymentProcessor.type.fieldApiName] === CARDKNOX_TYPE && isElectronic) {
            const merchantGlAccountId = processor[PaymentProcessor.merchantGlAccount.fieldApiName];
            this.wrappedBilling.cashReceipt['bank-account'] = merchantGlAccountId;
        }
    }

    prepareTestModeWarningMessage(selectedPPId) {
        const paymentProcessorDetailsByIds = this.paymentInfo.paymentDetails?.paymentProcessorDetailsByIds;
        this.prepareWarningMessages(
            (paymentProcessorDetailsByIds &&
                paymentProcessorDetailsByIds[selectedPPId] &&
                paymentProcessorDetailsByIds[selectedPPId]['isTestMode'])
            && [TEST_MODE_WARNING_MESSAGE]
            || null
        );
    }
    prepareWarningMessages(warningMessages) {
        this.warningMessages = warningMessages && [...warningMessages];
    }
    handleSelectionChange(evt) {
        this.wrappedBilling.additionalLookupValues.wrappedObjectsInfo.forEach(item => {
            if (item.controllingField === evt.detail.fieldName
                    && this.wrappedBilling.cashReceipt[evt.detail.fieldName] !== evt.detail.recordId) {
                this.wrappedBilling.cashReceipt[item.fieldName] = null;
                item.selectedValue = null;
                return item;
            }
        });
        this.wrappedBilling.cashReceipt[evt.detail.fieldName] = evt.detail.recordId;
    }
    handleAdditionFieldDataChange(evt) {
        if((this.wrappedBilling.cashReceipt[evt.detail.apiName] || evt.detail.value !== '') && this.wrappedBilling.cashReceipt[evt.detail.apiName] !== evt.detail.value){
            this.wrappedBilling.cashReceipt[evt.detail.apiName] = evt.detail.value;
        }
        if(evt.detail.isPicklistChange){
            for (let column of this.wrappedBilling.fieldSetColumns.mainColumns){
                if(column?.dependentOn === evt.detail.apiName){
                    this.wrappedBilling.cashReceipt[column.apiName] = ''; 
                }
            }
        }
    }
}