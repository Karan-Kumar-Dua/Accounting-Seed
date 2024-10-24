import { LightningElement, api, track, wire } from 'lwc';
import { LabelService } from 'c/utils';
import { CashReceipt,Billing } from 'c/sobject';
import Labels from './labels';
import nextCheckNumber from '@salesforce/apex/RefundHelper.nextCheckNumber';
import crRefundAdditionalFields from '@salesforce/apex/RefundHelper.crRefundAdditionalFields';

const CR_MAIN_FIELDS = new Set([
    CashReceipt.amount.fieldApiName,
    CashReceipt.receipt_date.fieldApiName,
    CashReceipt.bank_account.fieldApiName,
    CashReceipt.payment_type.fieldApiName,
    CashReceipt.payment_reference.fieldApiName
]);

export default class ReceiptRefund extends LightningElement {
    labels = {...LabelService, ...Labels};
    @api title;
    @api errorObjectLabel;
    @api objectName;
    @api amountTitle;
    @api amountHelp;
    @api amountValue;
    @api dateTitle;
    @api dateHelp;
    @api dateValue;
    @api bankAccount;
    @api bankAccountValue;
    @api bankAccountSearchObject;
    @api bankAccountSearchDisplayField;
    @api bankAccountSearchFilter;
    @api paymentType;
    @api paymentReference;
    @api paymentReferenceValue;
    @api memo;
    @api record;
    @api recordId;
    @api paymentTypeOptions;
    @api paymentTypeValue;    
    @api userPermissionEnabled;
    @api confirmButtonDisabled;
    @api errorMessageInfo;
    @api showTheSpinner;
    @api knowledgeArticleLink;

    @track balanceLabel=undefined;
    @track dataIds = {
        refundAmountInput: 'lightningInput-refundAmount',
        refundDateInput: 'lightningInput-refundDate',
        bankAccount: 'cLookup-bankAccount',
        paymentTypeCombobox: 'lightningCombobox-paymentType',
        referenceTextArea: 'lightningTextarea-reference',
        memoTextArea: 'lightningTextarea-memo'
    };
    @track additionalFields = [];
    @track nextCheckNum;
    @track cashReceiptRowData = {};
    @wire(crRefundAdditionalFields, {sObjectName : '$objectName', recordId : '$recordId'})
    fetchCRRefundAdditionalFields({ data, error }) {
        data && (this.additionalFields = data.mainColumns
            .filter(item => !CR_MAIN_FIELDS.has(item.apiName))
            .map(item => ({
                ...item,
                isMemoField: item.apiName === CashReceipt.memo.fieldApiName,
                isCommonField: item.apiName !== CashReceipt.memo.fieldApiName && !item.isLookup,
                isLookup : item.isLookup
            })));
        let tempDataVar = {};
        this.additionalFields && this.additionalFields.forEach(item => {
            tempDataVar[item.apiName] = item.value;
        });
        this.cashReceiptRowData = tempDataVar;
    }

    @wire(nextCheckNumber, { bankAccountId: "$bankAccountValue", timeStamp: Date.now() })
    fetchNextCheckNumber({ data, error }) {
        this.nextCheckNum = data;
        this.presetCheckNumber();
    }
    handleBankAccountChange(evt){
        if(evt.detail && evt.detail.recordId){
            if(evt.detail.recordId === ''){
                this.nextCheckNum = 0;
                this.presetCheckNumber();
            }else{
                nextCheckNumber({bankAccountId: evt.detail.recordId, timeStamp: Date.now()})
                .then(data => {
                    this.nextCheckNum = data;
                    this.presetCheckNumber();
                })
                .catch(error =>{})
            }
        }else{
            this.nextCheckNum = 0;
            this.presetCheckNumber();
        }
    }
    get disableConfirmButton() {
        return this.confirmButtonDisabled || this.showTheSpinner;
    }

    get isMemo() {
        return this.memo && (!this.isCashReceipt && !this.isCreditMemo);
    }
    get cashRecieptObjectName(){
        return CashReceipt.objectApiName;
    }
    get cashReceiptId(){
        return this.isCashReceipt ? this.recordId : '';
    }
    get isCashReceiptOrCreditMemo(){
        return this.isCashReceipt || this.isCreditMemo;
    }
    get isCashReceipt() {
        return this.objectName === CashReceipt.objectApiName;
    }
    get isCreditMemo(){
        return this.objectName === Billing.objectApiName;
    }

    presetCheckNumber() {
        const checkNumberInput = this.template.querySelector(`lightning-input-field[data-id="${CashReceipt.check_number.fieldApiName}"]`);
        if ((this.nextCheckNum || this.nextCheckNum === 0) && checkNumberInput) {
            checkNumberInput.value = this.nextCheckNum;
        }
    }

    handleCancel(){
        this.dispatchEvent(new CustomEvent("cancel"));
    }

    handleConfirm(){
        let parameters = [];
        for (let dataKey of Object.keys(this.dataIds)) {
            let dataId = this.dataIds[dataKey];
            const input = this.template.querySelector(`[data-id=${dataId}]`);
            if(dataKey !== "bankAccount"){
                if(dataKey === "refundAmountInput" && this.balanceLabel !== undefined){
                    parameters.push({input: input, inputName: input.name, inputValue: input.value, errorLabel: this.balanceLabel});
                }
                else{
                    parameters.push({input: input, inputName: input.name, inputValue: input.value});
                }
            }
            else{
                parameters.push({input: input, inputName: "bankAccount", inputValue: (input.getSelection())[0].id});
            }
        }
        this.isAdditionalFormValid = true;
        const additionalForm = this.template.querySelector('lightning-record-edit-form');
        if (additionalForm) {
            this.isAdditionalFormValid = false;
            this.template.querySelector('[data-id="submit-form"]')?.click();
        }
        if(this.validate(parameters) === true && this.isAdditionalFormValid){
            this.dispatchEvent(new CustomEvent("confirm", {detail: { parameters, additionalParams: this.additionalParams }}));
        }
    }

    handleAdditionalFormSubmit(event) {
        event.preventDefault();
        event.stopPropagation();

        this.additionalParams = {...this.cashReceiptRowData, ...JSON.parse(JSON.stringify(event.detail.fields))};
        this.additionalParams[CashReceipt.check_number.fieldApiName] = (this.additionalParams[CashReceipt.check_number.fieldApiName] && this.additionalParams[CashReceipt.check_number.fieldApiName] !== '') ? 
                                Number(this.additionalParams[CashReceipt.check_number.fieldApiName]) : this.nextCheckNum ? this.nextCheckNum : 0;
        this.isAdditionalFormValid = true;

    }

    handleAdditionalFormLoad(event) {
        event.preventDefault();
        event.stopPropagation();

        this.presetCheckNumber();
    }

    validate(parameters){
        let flag = true;
        for(let param of parameters){
            if (!param?.input.reportValidity() || (param.inputValue === undefined && param.inputName !== "memoTextArea")) {
                flag = false;
            }
        }
        return flag;
    }

    handleRefundAmountChange(event){
        const value = event.target.value;
        let message;
        if(this.errorObjectLabel === 'Cash Receipt'){
            message = LabelService.refundAmountExceededBalanceError;
        }
        else{
            message = LabelService.refundAmountExceededBalanceError;
        }
        message = message.replace("{0}", this.errorObjectLabel.toLowerCase());
        if(Math.abs(value) > Math.abs(this.amountValue)){
            this.balanceLabel = message;
        }
        else{
            this.balanceLabel = undefined;
        }
    }
    handleSelectionChange(evt){
        if(!evt.detail || this.cashReceiptRowData[evt.target.dataset.id] !== evt.detail.recordId){
            let hasDependencies = false;
            let dependentFieldName = '';
            let tempFields = JSON.parse(JSON.stringify(this.additionalFields));
            tempFields.forEach(item =>{
                if(item.apiName === evt.target.dataset.id){
                    item.value = evt?.detail?.recordId;
                }
                if(item.isDependent){
                    item.lookupControllingFields.forEach(field => {
                        if(field === evt.target.dataset.id){
                            hasDependencies = true;
                            dependentFieldName = item.apiName;
                            item.value = null; 
                        }
                    })
                }
            });
            if(hasDependencies){
                let lookups = this.template.querySelectorAll('c-x-lookup');
                if(lookups.length > 0){
                    lookups.forEach(item => {
                        if(item.sobjectFieldName === dependentFieldName){
                            item.forceClearSelection();
                        }
                    })
                }
                this.cashReceiptRowData[dependentFieldName] = null;
                this.additionalFields = tempFields;
            }
            this.cashReceiptRowData[evt.target.dataset.id] = evt?.detail?.recordId;
        }
    }
    get row(){
        return this.cashReceiptRowData;
    }
    handleMemoChange(evt){
        this.cashReceiptRowData[CashReceipt.memo.fieldApiName] = evt.target.value;
    }
}