import {api, track, wire} from 'lwc';
import {AccountingPeriod, LedgerHierarchy} from "c/sobject";
import {getObjectInfo} from "lightning/uiObjectInfoApi";
import {Constants, ErrorUtils, ModalLightningElement, LabelService} from 'c/utils';
import runConsolidation from '@salesforce/apex/ConsolidationsHelper.runConsolidation';
import isRunConsolidationRoutineAccessAllowed from '@salesforce/apex/ConsolidationsHelper.isRunConsolidationRoutineAccessAllowed';
import {keywords} from "c/lookupKeywords";
import Labels from './labels';

const REQUIRED_FIELD_MISSING_ERROR_MSG = LabelService.commonCompleteThisField;

export default class ConsolidationRunConfirmation extends ModalLightningElement {
    labels = {...LabelService, ...Labels};
    accountingPeriod = AccountingPeriod;

    ledgerLabel;

    accountingPeriodFilter = {
        type: keywords.type.STRING,
        field: this.accountingPeriod.status.fieldApiName,
        op: keywords.op.IN,
        val: [Constants.ACCT_PERIOD.STATUS_CLOSED, Constants.ACCT_PERIOD.STATUS_ARCHIVED]
    }

    runConsolidationRoutineAccessAllowed = false;
    showRunConsolidationRoutineAccessDeniedMsg = false;

    @api 
    get lastPeriodClosed() {
        return this.lastPeriodClosedId;
    }
    set lastPeriodClosed(p) {
        this.lastPeriodClosedId = p && p.Id;
        this.selectedPeriodId = this.lastPeriodClosedId;
    }

    lastPeriodClosedId;
    selectedPeriodId;

    @track hasSpinner = false;
    @track error;

    @wire(getObjectInfo, { objectApiName: LedgerHierarchy.objectApiName})
    ledgerHierarchyInfo({data,error}){
        if(data){
            this.ledgerLabel = data.fields[LedgerHierarchy.ledger.fieldApiName].label;
        }
    }

    connectedCallback() {
        isRunConsolidationRoutineAccessAllowed()
            .then(result => {
                this.runConsolidationRoutineAccessAllowed = result;
                this.showRunConsolidationRoutineAccessDeniedMsg = !result;
            });
        this.registerDataRetriever();
    }

    registerFocusElement() {
        const self = this;
        this.dispatchEvent(new CustomEvent('registerfocuselement', {
            bubbles: true,
            detail: {
                focusElement: () => {
                    return self.template.querySelector('c-lookup');
                }
            }
        }));
    }

    validateForm() {
        let isValid = true;
        !this.selectedPeriodId && (
            this.setPeriodLookupErrors([{message: REQUIRED_FIELD_MISSING_ERROR_MSG}]),
                isValid = false
        );
        return { isValid };
    }

    setPeriodLookupErrors(errors) {
        let accountingPeriodLookup = this.template.querySelector('c-lookup[data-id=accountingPeriod]');
        accountingPeriodLookup && (accountingPeriodLookup.errors = errors && errors.map((error, index) => ({...error, id: index})));
    }

    registerDataRetriever() {
        this.dispatchEvent(new CustomEvent('registerdataretriever', {
            bubbles: true,
            detail: {
                dataRetrieverCallback: ({id, name, runWithChildren}) => {
                    this.ledgerHierarchyId = id;
                    this.ledgerHierarchyName = name;
                    this.runWithChildren = runWithChildren;
                }
            }
        }));
    }

    setAccountingPeriod(event) {
        this.selectedPeriodId = event.detail && event.detail.recordId;
        this.setPeriodLookupErrors(!this.selectedPeriodId && [{message: REQUIRED_FIELD_MISSING_ERROR_MSG}] || []);
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleRun() {
        this.error = null;
        this.showSpinner();
        const { isValid } = this.validateForm();
        !isValid && (this.hideSpinner());
        isValid && runConsolidation({parentLedgerHierarchyId: this.ledgerHierarchyId, periodId: this.selectedPeriodId, runWithChildren: this.runWithChildren})
            .then(result => {
                if (result.isSuccess) {
                    this.dispatchEvent(new CustomEvent('success'));
                } else {
                    this.processCustomErrorResult(result);
                }
            })
            .catch(e => this.processError(e))
            .finally(() => this.hideSpinner());
    }

    processCustomErrorResult = result => {
        this.error = result.errors.length && result.errors[0].detail || Labels.ERR_RUNNING_CONSOLIDATION_ROUTINE;
    }

    processError(e) {
        let {error} = ErrorUtils.processError(e);
        this.error = error;
    }

    showSpinner() {
        this.hasSpinner = true;
    }

    hideSpinner() {
        this.hasSpinner = false;
    }
}