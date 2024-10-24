import { api, LightningElement, wire, track} from 'lwc';
import {FinancialReportResult, AccountingPeriod, GlAccount, Project, ProjectTask, Ledger} from 'c/sobject';
import getLedgerInquiryDefaults from '@salesforce/apex/FinancialReporterHelper.getLedgerInquiryDefaults';
import runLedgerInquiry from '@salesforce/apex/FinancialReporterHelper.runLedgerInquiry';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { keywords } from 'c/lookupKeywords';
import { ErrorUtils, NotificationService, Constants, LabelService } from 'c/utils';
import Labels from './labels';

const RUN_ERROR = 'An error occurred while running the report.';
const LINE_LIMIT_ERROR = 'The first 5000 results are displayed. Please refine your search criteria.';
const SOURCE_OPTIONS_FS = [
    {label: LabelService.commonAll, value: 'all'},
    {label: Labels.INF_AMORTIZATION_ENTRY, value: 'amortizationEntry'},
    {label: Labels.INF_AP_DISBURSEMENT, value: 'apd'},
    {label: LabelService.commonBilling, value: 'billing'},
    {label: Labels.COMMON_BILLING_CASH_RECEIPT, value: 'bcr'},
    {label: LabelService.commonBillingLine, value: 'billingLine'},
    {label: LabelService.commonCashDisbursement, value: 'cd'},
    {label: LabelService.commonCashReceipt, value: 'cr'},
    {label: LabelService.commonJournalEntryLine, value: 'jel'},
    {label: LabelService.commonPayable, value: 'payable'},
    {label: LabelService.commonPayableLine, value: 'payableLine'},
    {label: Labels.INF_TIME_CARD_DAY, value: 'timeCardDay'}
];
const SOURCE_OPTIONS_ERP = [
    {label: Labels.INF_INBOUND_INV_MVMT, value: 'iim'},
    {label: Labels.INF_MANUFACTURING_INV_MVMT, value: 'mim'},
    {label: Labels.INF_OUTBOUND_INV_MVMT, value: 'oim'},
    {label: Labels.INF_PURCHASE_ORDER_INV_MVMT, value: 'poim'},
    {label: Labels.INF_SALES_ORDER_INV_MVMT, value: 'soim'}
];
const AGGREGATED_BY_OPTIONS = [
    {label: LabelService.commonNone, value: 'none'},
    {label: Labels.INF_ACCOUNTS, value: 'accounts'},
    {label: LabelService.commonAccountingPeriod, value: 'period'},
    {label: LabelService.commonProduct, value: 'product'},
    {label: LabelService.commonProject, value: 'project'},
    {label: LabelService.commonProjectTask, value: 'projectTask'},
    {label: LabelService.commonSource, value: 'source'},
    {label: LabelService.commonGLAccount, value: 'glAccount'},
    {label: LabelService.commonGLVariable + ' 1', value: 'glav1'},
    {label: LabelService.commonGLVariable + ' 2', value: 'glav2'},
    {label: LabelService.commonGLVariable + ' 3', value: 'glav3'},
    {label: LabelService.commonGLVariable + ' 4', value: 'glav4'},
];

export default class FinReporterCriteriaLedgerInquiry extends LightningElement {
    labels = {...LabelService, ...Labels};
    /**
     * Ledger Inquiry Options DTO data type definition
     * @typedef LedgerInquiryOptions
     * ==== Props from the child class ================
     * @property {boolean} glAccountVariable1ReadAccess
     * @property {boolean} glAccountVariable2ReadAccess
     * @property {boolean} glAccountVariable3ReadAccess
     * @property {boolean} glAccountVariable4ReadAccess
     * @property {string} glAccountVariable1FieldLabel
     * @property {string} glAccountVariable2FieldLabel
     * @property {string} glAccountVariable3FieldLabel
     * @property {string} glAccountVariable4FieldLabel
     * @property {boolean} isErpEnabled
     * @property {boolean} isHlpMode
     * @property {string} glAccount
     * @property {string} product
     * @property {string} project
     * @property {string} projectTask
     * @property {string} account
     * @property {string} aggregatedBy
     * @property {string[]} source
     * ==== Props from the extended abstract class =====
     * @property {string} ledger
     * @property {string} glVariable1
     * @property {string} glVariable2
     * @property {string} glVariable3
     * @property {string} glVariable4
     * @property {string} startingAccountingPeriod
     * @property {string} endingAccountingPeriod
     */
    
    @api
    get values() {
        return this.runOptions;
    }

    @api defaultglaccountid;
    @api defaultAcctPeriod;
    @api defaultledgerid;
    @api defaultglav1;
    @api defaultglav2;
    @api defaultglav3;
    @api defaultglav4;

    @track selectedLedgerId;
    @track selectedLedgerType;


    financialReportResult = FinancialReportResult;
    accountingPeriod = AccountingPeriod;
    glAccount = GlAccount;
    project = Project;
    projectTask = ProjectTask;
    ledger = Ledger;

    /** @type {LedgerInquiryOptions} */
    @track runOptions = {};
    defaults = {};

    selectedGLAccountId;
    projectTaskFilter;
    loaded = false;
    isHideSpinner = false;
    loadedFromReportDrilldown = false;

    sourceOptions = SOURCE_OPTIONS_FS;
    sourceDefaultOptions = [SOURCE_OPTIONS_FS[0]];
    sourceSelectedValues = [];
    aggregatedByOptions = AGGREGATED_BY_OPTIONS;
    aggregatedByValue = 'none';
    runButtonDisabled = false;
    error;
    isError = false;

    ledgerFilter = {
        type: keywords.type.STRING,
        field: this.ledger.type1.fieldApiName,
        op: keywords.op.IN,
        val: [Constants.LEDGER.TYPE_TRANSACTIONAL, Constants.LEDGER.TYPE_ELIMINATIONS_TRANSACTIONAL]
    }

    get disableGLVarInputs() {
        return [Constants.LEDGER.TYPE_CONSOLIDATIONS_TRANSACTIONAL, Constants.LEDGER.TYPE_ELIMINATIONS_TRANSACTIONAL].includes(this.selectedLedgerType);
    }

    @wire(getRecord, {recordId: '$selectedLedgerId', fields: [Ledger.type1]})
    getRecordValues({data}) {
        if (data) {
            this.selectedLedgerType = getFieldValue(data, Ledger.type1);
        }
    }

    @wire(getLedgerInquiryDefaults)
    getDefaults({ data, error }) {
        if (data) {
            this.defaults = data;
            this.runOptions = {...data, ...this.runOptions};
            this.addErpSourceOption();
            this.filterSourceOptionsBasedOnPostingMode();
            this.filterAggregatedByOptionsBasedOnReadPermissions();
            this.relabelAggregatedByOptions();
            
            
            if(this.defaultAcctPeriod !== undefined){
                this.runOptions.startingAccountingPeriod = this.defaultAcctPeriod;
                this.runOptions.endingAccountingPeriod = this.defaultAcctPeriod
            }
            if(this.defaultglaccountid !== undefined){
                this.runOptions.glAccount = this.defaultglaccountid;
                this.selectedGLAccountId = this.defaultglaccountid;
            }
            if(this.defaultglav1 !== undefined){
                this.runOptions.glVariable1 = this.defaultglav1 === "" ? null : this.defaultglav1;
            }
            if(this.defaultglav2 !== undefined){
                this.runOptions.glVariable2 = this.defaultglav2 === "" ? null : this.defaultglav2; 
            }
            if(this.defaultglav3 !== undefined){
                this.runOptions.glVariable3 = this.defaultglav3 === "" ? null : this.defaultglav3;
            }
            if(this.defaultglav4 !== undefined){
                this.runOptions.glVariable4 = this.defaultglav4 === "" ? null : this.defaultglav4;
            }
            if(this.defaultledgerid !== undefined){
                this.runOptions.ledger = this.defaultledgerid;
                this.loadedFromReportDrilldown = true;
            }

            if (this.loadedFromReportDrilldown) {
                this.handleRun();
                this.displayResultsMessage();
            }

            this.loaded = true;
            this.isHideSpinner = true;

            
           
        } else if (error) {
            this.error = error;
            this.isError = true;
            this.loaded = true;
            this.isHideSpinner = true;
        }
    }

    displayResultsMessage() {
        NotificationService.displayToastMessage(
            this,
            Labels.INF_RESULTS_LOADING_ON_TRANSACTIONS,
            Labels.INF_SCROLL_DOWN_VIEW_TRANSACTIONS
        );
    }

    addErpSourceOption() {
        if (this.runOptions.isErpEnabled) {
            this.sourceOptions.push(...SOURCE_OPTIONS_ERP);
        }
    }

    filterSourceOptionsBasedOnPostingMode() {
        let filteredOptions = (this.runOptions.isHlpMode) ? ['billingLine', 'payableLine'] : ['billing', 'payable'];
        this.sourceOptions = this.sourceOptions.filter(opt => !filteredOptions.includes(opt.value));
    }

    filterAggregatedByOptionsBasedOnReadPermissions() {
        let filteredOptions = [];
        if (this.runOptions.glAccountVariable1ReadAccess !== true) {
            filteredOptions.push('glav1');
        }
        if (this.runOptions.glAccountVariable2ReadAccess !== true) {
            filteredOptions.push('glav2');
        }
        if (this.runOptions.glAccountVariable3ReadAccess !== true) {
            filteredOptions.push('glav3');
        }
        if (this.runOptions.glAccountVariable4ReadAccess !== true) {
            filteredOptions.push('glav4');
        }

        this.aggregatedByOptions = this.aggregatedByOptions.filter(opt => !filteredOptions.includes(opt.value));
    }

    relabelAggregatedByOptions() {
        this.aggregatedByOptions = this.aggregatedByOptions.map(opt => {
            if (opt.value === 'glav1') {
                opt.label = this.runOptions.glAccountVariable1FieldLabel;
            }
            else if (opt.value === 'glav2') {
                opt.label = this.runOptions.glAccountVariable2FieldLabel;
            }
            else if (opt.value === 'glav3') {
                opt.label = this.runOptions.glAccountVariable3FieldLabel;
            }
            else if (opt.value === 'glav4') {
                opt.label = this.runOptions.glAccountVariable4FieldLabel;
            }
            return opt;
        });
    }

    handleSourceOptionChange(event) {
        this.sourceSelectedValues = event.detail.value.split(";").filter(Boolean);
        this.runOptions.source = this.sourceSelectedValues;
    }

    handleAggregatedByOptionChange(event) {
        this.aggregatedByValue = event.detail.value;
        this.runOptions.aggregatedBy = this.aggregatedByValue;
    }

    setProjectTaskFilter(projectId) {
        this.projectTaskFilter = {}
        if (projectId) {
            this.projectTaskFilter = {
                type: keywords.type.ID,
                field: this.projectTask.project.fieldApiName,
                op: keywords.op.EQUAL,
                val: projectId
            }
        }
    }

    setLedger(event) {
        this.selectedLedgerId = event.detail && event.detail.recordId;
        this.runOptions.ledger = this.selectedLedgerId;
        this.clearGLVariables();
    }
    setStartPeriod(event) {
        this.runOptions.startingAccountingPeriod = event.detail && event.detail.recordId;
    }
    setEndPeriod(event) {
        this.runOptions.endingAccountingPeriod = event.detail && event.detail.recordId;
    }

    setGlAccount(event) {
        this.runOptions.glAccount = event.detail && event.detail.recordId;
        this.selectedGLAccountId = this.runOptions.glAccount;
    }

    setProject(event) {
        this.runOptions.project = event.detail.value != null && event.detail.value.recordId !== undefined ? event.detail.value.recordId : null;
        this.setProjectTaskFilter(this.runOptions.project);
    }

    setProjectTask(event) {
        this.runOptions.projectTask = event.detail.value != null && event.detail.value.recordId !== undefined ? event.detail.value.recordId : null;
    }

    setAccount(event) {
        this.runOptions.account = event.detail.value != null && event.detail.value.recordId !== undefined ? event.detail.value.recordId : null;
    }

    setProduct(event) {
        this.runOptions.product = event.detail.value != null && event.detail.value.recordId !== undefined ? event.detail.value.recordId : null;
    }

    setGLVar1(event) {
        this.runOptions.glVariable1 = event.detail.value[0];
    }
    setGLVar2(event) {
        this.runOptions.glVariable2 = event.detail.value[0];
    }
    setGLVar3(event) {
        this.runOptions.glVariable3 = event.detail.value[0];
    }
    setGLVar4(event) {
        this.runOptions.glVariable4 = event.detail.value[0];
    }

    handleRun() {
        this.error = null;
        this.isError = false;
        this.runButtonDisabled = true;
        this.isHideSpinner = false;
        runLedgerInquiry({options: JSON.stringify(this.runOptions)})
          .then(result => {
              if (!result.saveResponse.isSuccess) {
                  this.processCustomErrorResult(result);
              }
              if (result.limitedOutput) {
                  this.error = LINE_LIMIT_ERROR;
                  this.isError = true;
              }
              this.fireReportResultEvent(result);
              this.runButtonDisabled = false;
              this.isHideSpinner = true;
          }).catch(e => this.processError(e));
    }

    processError(e) {
        this.runButtonDisabled = false;
        this.isHideSpinner = true;
        let {isError, error} = ErrorUtils.processError(e);
        this.error = error;
        this.isError = isError;
    }

    processCustomErrorResult = result => {
        if (result.saveResponse.errors.length > 0) {
            this.error = result.saveResponse.errors[0].detail;
        }
        else {
            this.error = RUN_ERROR;
        }
        this.isError = true;
    }

    fireReportResultEvent(result) {
        this.dispatchEvent(new CustomEvent('ledgerinquiryresult', { detail: result}));
    }

    clearGLVariables() {
        const acctVariableFields = this.template.querySelectorAll('lightning-input-field[data-form="acct-variables"]');
        acctVariableFields && acctVariableFields.forEach(acctVariableField => {
            acctVariableField.reset();
        });
        this.runOptions.glVariable1 = null, this.runOptions.glVariable2 = null,
            this.runOptions.glVariable3 = null, this.runOptions.glVariable4 = null;
    }
}