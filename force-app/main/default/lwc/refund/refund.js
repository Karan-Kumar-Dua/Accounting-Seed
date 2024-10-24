import { LightningElement, api, wire, track } from 'lwc';
import { LabelService, NotificationService, CommonUtils } from 'c/utils';
import { CashReceipt } from 'c/sobject';
import { Billing } from 'c/sobject';
import { GlAccount } from 'c/sobject';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';
import { keywords } from 'c/lookupKeywords';
import getObjectName from '@salesforce/apex/RefundHelper.getObjectNameOfRecord';
import PAYMENT_TYPE_FIELD from '@salesforce/schema/Cash_Receipt__c.Payment_Type__c';
import GL_ACCOUNT_NAME_FIELD from '@salesforce/schema/GL_Account__c.Name';
import GL_ACCOUNT_BANK_FIELD from '@salesforce/schema/GL_Account__c.Bank__c';
import RECEIPT_REFUND from '@salesforce/customPermission/Issue_Cash_Receipt_Refund';
import { CloseActionScreenEvent } from 'lightning/actions';
import createRefund from '@salesforce/apex/RefundHelper.createRefund';
import Labels from './labels';

const cashReceipt = CashReceipt;
const glAccount = GlAccount;
const billing = Billing;

const cashReceiptFields = [
    `${cashReceipt.objectApiName}.${cashReceipt.bank_account.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.bank_account_r_name.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.payment_reference.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.payment_type.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.balance.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.cash_receipt_name.fieldApiName}`,
    `${cashReceipt.objectApiName}.${cashReceipt.memo.fieldApiName}`
];

const billingFields = [
    `${billing.objectApiName}.${billing.balance.fieldApiName}`,
    `${billing.objectApiName}.${billing.name_field.fieldApiName}`,
    `${billing.objectApiName}.${billing.type.fieldApiName}`
];

const issueCashReceiptRefund = Labels.INF_ISSUE_CASH_RECEIPT_REFUND;
const issueCreditMemoRefund = Labels.INF_ISSUE_CREDIT_MEMO_REFUND;
const cashReceiptLabel = Labels.COMMON_CASH_RECEIPT;
const creditMemoLabel = Labels.COMMON_CREDIT_MEMO;

export default class Refund extends LightningElement {

    @track objectLabel;
    @track refundTitle;
    @track refundAmountTitle;
    @track refundAmountHelp;
    @track refundAmountValue;
    @track refundDateTitle;
    @track refundDateHelp;
    @track refundDateValue;
    @track refundBankAccount;
    @track refundBankAccountValue;
    @track refundBankAccountSearchObject;
    @track refundBankAccountSearchDisplayField;
    @track refundBankAccountSearchFilter;
    @track refundPaymentType;
    @track refundPaymentReference;
    @track refundPaymentReferenceValue;
    @track refundMemo;
    @track refundRecord;
    @track paymentTypeOptions;
    @track paymentTypeValue;
    @track userPermitted = true;
    @track confirmDisabled = false;
    @track errorMessage;
    @track showSpinner = true;
    @track errors;
    glAccountFilter = {
        type: 'Boolean',
        field: GL_ACCOUNT_BANK_FIELD.fieldApiName,
        op: keywords.op.EQUAL,
        val: true
    };
    @track objectName;
    @track fields;
    label = LabelService;
    @track knowledgeArticleLink;


    @api recordId;

    @wire(getObjectName, { recordId: '$recordId' })
    wiredGetObjectName(result) {
        const { data, error } = result;
        if (data) {
            this.objectName = data;
            if (this.objectName === billing.objectApiName) {
                this.fields = billingFields;
                this.objectLabel = creditMemoLabel;
                this.knowledgeArticleLink = "https://support.accountingseed.com/hc/en-us/articles/4874187231507" ;
            }
            else {
                this.fields = cashReceiptFields;
                this.objectLabel = cashReceiptLabel;
                this.knowledgeArticleLink = "https://support.accountingseed.com/hc/en-us/articles/4880399781907";
            }
            this.errors=false;
        }
        if (error) {
            this.errors=true;
            NotificationService.displayToastMessage(
                this,
                error.body.message,
                `${LabelService.commonToastErrorTitle}:`,
                'error'
            );
            this.closeAction();
        }
    }

    @wire(getObjectInfo, { objectApiName: cashReceipt.objectApiName })
    cashReceiptObjectInfo;

    @wire(getRecord, { recordId: '$recordId', fields: '$fields' })
    wiredGetRecord(result) {
        const { data, error } = result;
        if (data) {
            this.refundRecord = data.fields;
            this.checkIssueCashReceiptRefundAllowed();
            this.arrangeTheValues();
            this.showSpinner = false;
        }
        if (error) {
            NotificationService.displayToastMessage(
                this,
                error.body.message,
                `${LabelService.commonToastErrorTitle}:`,
                'error'
            );
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$cashReceiptObjectInfo.data.defaultRecordTypeId', fieldApiName: PAYMENT_TYPE_FIELD })
    wiredPicklistValues({ error, data }) {
        this.paymentTypeOptions = undefined;
        if (data) {
            this.paymentTypeOptions = data.values;
            this.paymentTypeValue = data.defaultValue && data.defaultValue.value || data.values[0]?.value;
        }
        else if (error) {
            NotificationService.displayToastMessage(
                this,
                error.body.message,
                `${LabelService.commonToastErrorTitle}:`,
                'error'
            );
        }
    }

    arrangeTheValues() {
        let referenceValue = this.label.cashReceiptRefundReferenceMessage;
        this.refundAmountTitle = this.label.cashReceiptRefundAmountTitle;
        this.refundAmountValue = this.refundRecord[billing.balance.fieldApiName].value && Math.abs(this.refundRecord[billing.balance.fieldApiName].value);
        this.refundDateTitle = this.label.cashReceiptRefundDateTitle;
        this.refundDateHelp = this.label.cashReceiptRefundDateHelp;
        const dateISOFormat = new Date().toISOString();
        this.refundDateValue = dateISOFormat.substring(0, dateISOFormat.indexOf('T'));
        this.refundBankAccount = this.getBankAccount();
        this.refundBankAccountSearchObject = this.getGlAccountApiName();
        this.refundBankAccountSearchDisplayField = this.getGlAccountSearchField();
        this.refundBankAccountSearchFilter = this.glAccountFilter;
        this.refundPaymentType = this.getPaymentType();
        this.refundPaymentReference = this.getPaymentReference();
        this.refundMemo = this.getMemo();

        let message = this.label.cashReceiptRefundAccessError;        
        let amountHelp = this.label.cashReceiptRefundAmountHelp;
        let refTitle = this.label.cashReceiptRefundTitle;

        if (this.objectName === billing.objectApiName) {
            this.refundAmountHelp = amountHelp.replace("{0}", this.label.commonCreditMemo.toLowerCase());
            this.refundTitle = refTitle.replace('{0}', this.label.commonCreditMemo);
            message = message.replace('{0}', issueCreditMemoRefund);
            this.refundBankAccountValue = undefined;
        }
        else {
            const cashReceiptLabel = this.cashReceiptObjectInfo.data.label;
            this.refundAmountHelp = amountHelp.replace("{0}", cashReceiptLabel.toLowerCase());
            this.refundTitle = refTitle.replace('{0}', cashReceiptLabel);
            message = message.replace('{0}', issueCashReceiptRefund);
            this.refundBankAccountValue = this.refundRecord[cashReceipt.bank_account.fieldApiName].value;
        }
        referenceValue = referenceValue.replace('{0}', this.refundRecord.Name.value);
        this.refundPaymentReferenceValue = referenceValue;
        this.errorMessage = message;
    }

    getBankAccount() {
        return this.getCashReceiptFieldInfo(cashReceipt.bank_account.fieldApiName);
    }

    getPaymentReference() {
        return this.getCashReceiptFieldInfo(cashReceipt.payment_reference.fieldApiName);
    }

    getPaymentType() {
        return this.getCashReceiptFieldInfo(cashReceipt.payment_type.fieldApiName);
    }

    getMemo() {
        return this.getCashReceiptFieldInfo(cashReceipt.memo.fieldApiName);
    }

    getCashReceiptName() {
        return this.getCashReceiptFieldInfo(cashReceipt.cash_receipt_name.fieldApiName);
    }

    getGlAccountApiName() {
        return glAccount.objectApiName;
    }

    getGlAccountSearchField() {
        return GL_ACCOUNT_NAME_FIELD.fieldApiName;
    }

    getCashReceiptFieldInfo = (fieldName) => {
        if (this.cashReceiptObjectInfo?.data?.fields[fieldName]) {
            return {
                label: this.cashReceiptObjectInfo.data.fields[fieldName]?.label,
                hint: this.cashReceiptObjectInfo.data.fields[fieldName]?.inlineHelpText
            }
        }
        return undefined
    }

    checkIssueCashReceiptRefundAllowed() {
        this.userPermitted = RECEIPT_REFUND;
        this.confirmDisabled = !this.userPermitted;
    }

    handleCancelClick() {
        this.closeAction();
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    /**
     * Method used to handle confirm click
     * fetch the value with event.detail
     * [
     *     {"inputName":"refundAmountInput","inputValue":"200"}, or {"inputName":"refundAmountInput","inputValue":"200", errorLabel: <If the amount greater than balance>},
     *     {"inputName":"refundDateInput","inputValue":"2022-3-10"},
     *     {"inputName":"bankAccount","inputValue":"a0i0R000002gHYUQA2"},
     *     {"inputName":"paymentTypeCombobox","inputValue":"Check"},
     *     {"inputName":"referenceTextArea","inputValue":"CR-00000 refund"},
     *     {"inputName":"memoTextArea"}
     *    ]
    */
    handleConfirmClick(event){
        this.showSpinner = this.confirmDisabled = true;
        const {parameters, additionalParams} = event.detail;
        let errorFlag = false;
        let paramValues = {};
        for (const res of parameters) {
            if (res.inputName === "refundAmountInput" && res.errorLabel !== undefined) {
                NotificationService.displayToastMessage(
                    this,
                    res.errorLabel,
                    `${LabelService.commonToastErrorTitle}:`,
                    'error'
                );
                errorFlag = true;
                break;
            }
            paramValues[res.inputName] = res.inputValue;
        }
        if(errorFlag === false){
            const outParamValues = JSON.stringify(paramValues);
            createRefund({ values: outParamValues, objectName: this.objectName, recordId: this.recordId, additionalParams : additionalParams })
            .then(result => {
                if (result.isSuccess) {
                    if (result.result && result.result[0]) {
                        const id = result.result[0].id;
                        const name = result.result[0].name;
                        const message = this.label.cashReceiptRefundConfirmationMessage;
                        NotificationService.displayCommonToastMessage(
                        this,
                        message,
                        [{
                            url: CommonUtils.getRecordViewPath(id),
                            label: name,
                        }],
                        '',
                        'success',
                        'dismissible'
                        );
                    }
                    this.closeAction();
                }
                else {
                    NotificationService.displayToastMessage(
                      this,
                      result.errors.length > 0 ? result.errors[0].detail : '',
                      `${LabelService.commonToastErrorTitle}:`,
                      'error'
                    );
                }
            })
            .catch(error => {
                NotificationService.displayToastMessage(
                    this,
                    error.body.message,
                    `${LabelService.commonToastErrorTitle}:`,
                    'error'
                );
            })
            .finally(() => this.showSpinner = this.confirmDisabled = false);
        }
        else {
            this.showSpinner = this.confirmDisabled = false;
        }
    }

}