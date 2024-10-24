import { LightningElement } from "lwc";
import { api } from 'lwc';
import {NotificationService, StreamingApi, WindowUtils, LabelService} from "c/utils";
import { getFieldValue, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { BankReconciliation, ASObjectEvent } from "c/sobject";
import getMultiCurrencyStatus from '@salesforce/apex/BankRecCalculatorHelper.getMultiCurrencyStatus';
import getAccountingPeriodStatus from '@salesforce/apex/BankRecCalculatorHelper.getAccountingPeriodStatus';
import Labels from './labels';

const CHANNEL_NAME = '/event/' + ASObjectEvent.packageQualifier + 'AS_Commit_Event__e';
const PAYMENTS = LabelService.commonPayments;
const DEPOSITS = LabelService.commonDeposits;
const CHARGES = LabelService.commonCharges;
const COMPLETED = LabelService.commonCompleted;
const IN_PROGRESS = LabelService.commonInProgress;
const WORKING = LabelService.commonWorking;
const AUTO_CLEAR_RUNNING = LabelService.commonAutoClearRunning;
const CREDIT_CARD = LabelService.commonCreditCard;

export default class BankRecCalculator2 extends LightningElement {
    labels = {...Labels, ...LabelService};
    br = BankReconciliation;
    objEvent = new ASObjectEvent();
    sa = new StreamingApi();
    noDifference = false;
    noGLDifference = false;
    isSpinner = false;
    isCompleted = false;
    isCompletedAndCurrencyMatches = false;
    isCredit = false;
    isClearJobRunning = false;
    working = false;
    currencyMismatch = false;      
    @api recordId;
    @api objectApiName;
    record;
    error;
    differenceClass;
    differenceGLClass;
    endingBalanceClass;
    glEndingBalanceClass;
    calculatedEndingBalanceClass;
    calculatedGLBalanceClass;
    clearedDisbursementsClass;
    unclearedPaymentsClass;
    clearedDepositsClass;
    unclearedDepositsClass;
    beginningBalanceClass;
    wu_pinnedIcon;
    wu_pinnedTitle;
    endDateInArchivedPeriod = false;

    handleLoad(event) {
        this.isSpinner = true;
        this.checkMultiCurrencyStatus().then(() =>{
            if (event.detail.records[this.recordId]) {
                this.previousStatus = this.record !== undefined ? getFieldValue(this.record, this.br.status) : '';
                this.record = event.detail.records[this.recordId];
                let recordStatus = getFieldValue(this.record, this.br.status);
                this.fieldAPIinfo = event.detail.objectInfos[this.objectApiName].fields;
                this.error = undefined;
                this.isCompleted = getFieldValue(this.record, this.br.status) === COMPLETED ? true : false;
                this.isCompletedAndCurrencyMatches = this.isCompleted && !this.currencyMismatch;
                this.noDifference = getFieldValue(this.record, this.br.uncleared_amount) === 0.00 ? true : false;
                this.noGLDifference = getFieldValue(this.record, this.br.gl_difference) === 0.00 ? true : false;
                this.differenceClass = getFieldValue(this.record, this.br.uncleared_amount) < 0.00 ? "slds-text-heading_small slds-text-color_error" : "slds-text-heading_small";
                this.differenceGLClass = getFieldValue(this.record, this.br.gl_difference) < 0.00 ? "slds-text-heading_small slds-text-color_error" : "slds-text-heading_small";
                this.endingBalanceClass = getFieldValue(this.record, this.br.ending_balance) < 0.00 ? "slds-text-color_error" : "";
                this.glEndingBalanceClass = getFieldValue(this.record, this.br.gl_ending_balance) < 0.00 ? "slds-text-color_error" : "";
                this.calculatedEndingBalanceClass = getFieldValue(this.record, this.br.calculated_ending_balance) < 0.00 ? "slds-text-color_error" : "";
                this.calculatedGLBalanceClass = getFieldValue(this.record, this.br.calculated_gl_balance) < 0.00 ? "slds-text-color_error" : "";
                this.clearedDisbursementsClass = getFieldValue(this.record, this.br.cleared_disbursements) < 0.00 ? "slds-text-color_error" : "";
                this.unclearedPaymentsClass = getFieldValue(this.record, this.br.uncleared_payments) < 0.00 ? "slds-text-color_error" : "";
                this.clearedDepositsClass = getFieldValue(this.record, this.br.cleared_deposits) < 0.00 ? "slds-text-color_error" : "";
                this.unclearedDepositsClass = getFieldValue(this.record, this.br.uncleared_deposits) < 0.00 ? "slds-text-color_error" : "";
                this.beginningBalanceClass = getFieldValue(this.record, this.br.beginning_balance) < 0.00 ? "slds-text-color_error" : "";
                this.isCredit = getFieldValue(this.record, this.br.type1) === CREDIT_CARD ? true : false;
                this.working = getFieldValue(this.record, this.br.status) === WORKING ? true : false;

                this.checkAccountingPeriodStatus();

                if (this.previousStatus === WORKING && recordStatus === COMPLETED) {
                    this.previousStatus = recordStatus;
                    NotificationService.displayToastMessage(
                        this,
                        Labels.INF_RECONCILIATION_SUCCESSFULLY_COMPLETED,
                        Labels.INF_RECONCILIATION_COMPLETE,
                        'success'
                    );
                }
                
                if (this.previousStatus === IN_PROGRESS && recordStatus === WORKING) {
                    this.previousStatus = recordStatus;
                    NotificationService.displayToastMessage(
                        this,
                        Labels.INF_BANK_REC_CALCULATION_UPDATED_RECONCILIATION_COMPLETED,
                        Labels.INF_RECONCILIATION_IN_PROGRESS,
                        'success'
                    );                
                }

                if (this.isClearJobRunning === true && recordStatus !== AUTO_CLEAR_RUNNING) {
                    NotificationService.displayToastMessage(
                        this,
                        Labels.INF_BANK_RECONCILIATION_CREATION_IN_PROCESS,
                        Labels.INF_AUTO_CLEAR_JOB_IN_PROGRESS,
                        'info'
                    );                
                }
                if (recordStatus === AUTO_CLEAR_RUNNING) {
                    NotificationService.displayToastMessage(
                        this,
                        Labels.INF_BT_DATE_POPULATED_AUTO_CLEARED,
                        Labels.INF_AUTO_CLEAR_JOB_IN_PROGRESS,
                        'info'
                    )
                }

                this.isSpinner = false;
            } else if (error) {
                this.isSpinner = false;
                this.error = error;
                this.record = undefined;
            }
        });
    }

    checkAccountingPeriodStatus() {
        this.endDateInArchivedPeriod = false;
        if (this.record && getFieldValue(this.record, this.br.end_date)) {
            return getAccountingPeriodStatus({theDate: getFieldValue(this.record, this.br.end_date)})
                .then(result => {
                    if (result === 'Archived' || result === 'Archive In Progress') {
                        this.endDateInArchivedPeriod = true;
                    }
                });
        }
    }

    checkMultiCurrencyStatus(){
        this.isSpinner = true;
        return getMultiCurrencyStatus({
            bankRecId: this.recordId
        }).then(result => {
            if (result.isSuccess) {
                this.currencyMismatch = result.currencyMismatch;
                this.isCompletedAndCurrencyMatches = this.isCompleted && !this.currencyMismatch;
                this.isClearJobRunning = result.isClearJobRunning;
                this.isSpinner = false;
            } else {
                this.error = result.errors;
                this.isSpinner = false;
            }
        })
        .catch(error => {
            this.isSpinner = false;
            this.error = Labels.ERR_DURING_LOAD;
            if (Array.isArray(error.body)) {
                this.error = error.body.map(e => e.message).join (', ');
            } else if (typeof error.body === 'string') {
                this.error = error.body;
            }
            
        });
    }

    get unclearedPaymentsLabel() {
        const unclearedPaymentsAPIName = (this.br.uncleared_payments && this.br.uncleared_payments.fieldApiName) ? this.br.uncleared_payments.fieldApiName : this.br.packageQualifier + 'UnCleared_Payments__c';
        return this.replacePaymentsLabel(this.fieldAPIinfo[unclearedPaymentsAPIName].label);
    }

    get clearedDisbLabel() {
        const clearedDisbursementsAPIName = (this.br.cleared_disbursements && this.br.cleared_disbursements.fieldApiName) ? this.br.cleared_disbursements.fieldApiName : this.br.packageQualifier + 'Cleared_Disbursements__c';
        return this.replacePaymentsLabel(this.fieldAPIinfo[clearedDisbursementsAPIName].label);
    }

    get unclearedDepositsLabel() {
        const unclearedDepositsAPIName = (this.br.uncleared_deposits && this.br.uncleared_deposits.fieldApiName) ? this.br.uncleared_deposits.fieldApiName : this.br.packageQualifier + 'UnCleared_Deposits__c';
        return this.replaceDepositsLabel(this.fieldAPIinfo[unclearedDepositsAPIName].label);
    }

    get clearedDepositsLabel() {
        const clearedDepositsAPIName = (this.br.cleared_deposits && this.br.cleared_deposits.fieldApiName) ? this.br.cleared_deposits.fieldApiName : this.br.packageQualifier + 'Cleared_Deposits__c';
        return this.replaceDepositsLabel(this.fieldAPIinfo[clearedDepositsAPIName].label);
    }

    get calculatedGLBalanceLabel() {
        return this.fieldAPIinfo[this.br.calculated_gl_balance.fieldApiName].label;
    }

    get calculatedEndingBalanceLabel() {
        return this.fieldAPIinfo[this.br.calculated_ending_balance.fieldApiName].label;
    }

    get endingBalanceLabel() {
        return this.fieldAPIinfo[this.br.ending_balance.fieldApiName].label;
    }

    get beginningBalanceLabel() {
        return this.fieldAPIinfo[this.br.beginning_balance.fieldApiName].label;
    }

    get glEndingBalanceLabel() {
        return this.fieldAPIinfo[this.br.gl_ending_balance.fieldApiName].label;
    }

    get showArchivedPeriodWarning() {
        return this.isCompleted && this.endDateInArchivedPeriod;
    }

    replacePaymentsLabel(label) {
        return this.isCredit === true ? label.replace(PAYMENTS,CHARGES) : label;
    }

    replaceDepositsLabel(label) {
        return this.isCredit === true ? label.replace(DEPOSITS,PAYMENTS) : label;
    }

    connectedCallback() {
        this.sa.channelName = CHANNEL_NAME;
        this.sa.customErrorCallback = this.errorCallback;
        this.sa.handleSubscribe(this.updateCallback);
        this.wu = new WindowUtils(this, '[data-id="calculator"]');
        this.wu.addPinFunction();
    }

    disconnectedCallback() {
        this.sa.handleUnsubscribe();
        this.wu.removePinFunction();
    }

    handlePinned() {
        this.wu.handlePinned();
    }

    updateCallback = response => {
        if (response) {
            if (response.data.payload[this.objEvent.record_id] === this.recordId) {
                getRecordNotifyChange([{recordId: this.recordId}]);
                // Response contains the payload of the new message received
            }
        }
    };

    errorCallback = error => {
        if (error.hasOwnProperty('error') && !this.sa.isInternalError(error.error)) {
            this.error = error;
        }
    };
}