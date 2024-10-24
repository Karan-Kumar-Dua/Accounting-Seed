import { api, track } from 'lwc';
import {
    DateUtils,
    NavigationService,
    NotificationService,
    SortStrategyFactory,
    CommonUtils,
    ErrorUtils,
    LabelService
} from "c/utils";
import {CashReceipt} from 'c/sobject';
import BillingStore from './billingStore';
import Helper from './cashReceiptApplyHelper';
import CURRENCY from '@salesforce/i18n/currency';
import getApplicableInvoices from '@salesforce/apex/CashReceiptApplyHelper.getApplicableInvoices'
import loadCashReceipt from '@salesforce/apex/CashReceiptApplyHelper.getCashReceipt'
import loadExtraColumns from '@salesforce/apex/CashReceiptApplyHelper.getExtraColumns'
import save from '@salesforce/apex/CashReceiptApplyHelper.save';
import LANG from '@salesforce/i18n/lang';
import Labels from './labels';

const OVERAPPLIED_INVOICE = LabelService.errorBillingBalanceNotLessThanZero;
const OVERAPPLIED_CREDIT = Labels.ERR_CR_BALANCE_CANNOT_LESS_THAN_0;
const APPLIED_AMOUNT_LESS_THAN_ZERO = Labels.ERR_RECIEVED_AMT_CANNOT_LESS_THAN_0;
const INVOICE_LOAD_ERROR = Labels.ERR_LOADING_ASSOCIATED_INVOICES;
const CASH_RECEIPT_LOAD_ERROR = Labels.ERR_LOADING_CASH_RECEIPT;
const CASH_RECEIPT_MODIFIED_ERROR = Labels.ERR_CR_MODIFIED_REFRESH;

const ADJUSTMENT_GL_ACCOUNT_REQUIRED = Labels.ERR_ADJUSTMENT_GL_ACCT_REQ;
const VALUE_REQUIRED = LabelService.commonValueReq;

const OBJECT_API_NAME = 'AcctSeed__Cash_Receipt__c';
const KEY_FIELD = 'billingId';
const MAX_INVOICES_LOADED = 2001;



export default class CashReceiptApply extends NavigationService {
    labels = {...LabelService, ...Labels};
    objectApiName = OBJECT_API_NAME;
    keyField = KEY_FIELD;
    billingStore = new BillingStore();
    sortFactory;
    provisionedRecord;
    periodStart;
    
    @api 
    set recordId(val) {
        if (val) {
            this._recordId = val;
            this.getCashReceipt();
        }
    }
    get recordId() {
        return this._recordId;
    }
    @api invoices;

    @track extraColumns;
    @track isError = false;
    @track error;
    @track isSpinner = false;    
    @track columns;
    @track name = '';
    @track receiptDate;
    @track total = 0;
    @track amount = 0;
    @track applied = 0;
    @track customer;
    @track customerName;
    @track billingNumber;
    @track postingStatus = "Posted";
    @track billingDateStart;
    @track billingDateEnd;
    @track dueDateStart;
    @track dueDateEnd;
    @track originalApplied;
    @track originalAmount;
    @track originalTotal;
    @track billingAmountStart;
    @track billingAmountEnd;
    @track displayData = [];
    @track validFilter;
    @track showPopup = false;
    @track currencyCode = CURRENCY;    
    @track isMultiCurrencyEnabled = false;
    @track sortOpts = {
        sortedBy: 'URL',
        sortedDirection: 'asc'
    };
    @track cnvCharge = 0;
    
    get balance() {
        let balance = (parseFloat(this.total || 0).toFixed(5) - parseFloat(this.applied || 0).toFixed(5) - parseFloat(this.cnvCharge).toFixed(5)).toFixed(5);
        const zero = parseFloat(0).toFixed(5);
        return Math.abs(parseFloat(balance)).toFixed(5) === zero ? zero : balance; // to avoid -0 when using toFixed. example: (-0.0000000000001).toFixed(5) => -0.00000
    }

    get invoiceSectionTitle() {
        const totalInvoices = this.billingStore.getItems().length;
        const displayMax = this.maxInvoicesDisplayed;
        const displayedInvoices = totalInvoices > displayMax ? displayMax + '+' : totalInvoices;
        return 'Billings - (' + displayedInvoices + ')';
    }

    get maxInvoicesDisplayed() {
        return MAX_INVOICES_LOADED - 1;
    }

    getCashReceipt() {
        if (!this.recordId) {
            return;
        }

        this.isSpinner = true;
        loadCashReceipt({ cashReceiptId: this.recordId })
        .then(data => {
            var isValid = data.isValid !== undefined ? data.isValid : true;
            this.isError = !isValid;
            this.isMultiCurrencyEnabled = data.isMultiCurrencyEnabled;            
            this.lastModifiedDate = data.cashReceipt.LastModifiedDate;
            this.name = data.cashReceipt.Name;
            this.customer = data.cashReceipt.AcctSeed__Account__c;
            this.customerName = data.cashReceipt.AcctSeed__Account__r.Name;
            this.originalApplied = data.cashReceipt.AcctSeed__Applied_Amount__c;
            this.originalAmount = Math.abs(data.cashReceipt.AcctSeed__Amount__c);
            this.originalTotal = Math.abs(data.cashReceipt.AcctSeed__Amount__c);
            this.receiptDate = data.cashReceipt.AcctSeed__Receipt_Date__c;
            this.cnvCharge = data.cashReceipt.AcctSeed__Convenience_Fees_Charged__c || 0;
            this.displayData = this.getDisplayData(data.cashReceipt); 
            this.currencyCode = this.getCurrencyCode(data.cashReceipt);
            this.billingStore.setCurrency(this.currencyCode, this.isMultiCurrencyEnabled);
            this.getExtraColumns();
            this.getBillings();
            this.error = data.validationErrors;  
        })
        .catch(() => {
            this.error = CASH_RECEIPT_LOAD_ERROR;
            this.isSpinner = false;
        });
    }

    getExtraColumns() {
        return loadExtraColumns().then(result => {
            if (result){                
                this.extraColumns = result;     
            }
            else{
                this.error = INVOICE_LOAD_ERROR;
                this.isSpinner = false;
            }
        })
        .catch((exception) => {
            this.error = exception;
            this.isSpinner = false;
            
        });
    }
    
    getBillings(resetSorting = true) {
        var gridCmp = this.template.querySelector(".billingsGrid");
        this.isSpinner = true;
        this.amount = this.originalAmount;
        this.applied = this.originalApplied;
        this.total = this.originalTotal;
        return getApplicableInvoices({ 
            cashReceiptId: this.recordId,
            maxInvoices: MAX_INVOICES_LOADED,
            customerId: this.customer,
            postingStatus: this.postingStatus,
            billingNumber: this.billingNumber,
            billingDateStart: this.billingDateStart,
            billingDateEnd: this.billingDateEnd,
            dueDateStart: this.dueDateStart,
            dueDateEnd: this.dueDateEnd,
            billingAmountStart: this.billingAmountStart,
            billingAmountEnd: this.billingAmountEnd           
        }).then(result => {
            if (result){                
                this.billingStore.setItems(result.billingWrapper);
                this.invoices = this.billingStore.getItems();
                this.applied = result.totalAppliedAmount;
                this.initTable();
                this.sort(this.sortOpts.sortedBy, this.sortOpts.sortedDirection);
                if (resetSorting && gridCmp !== null) {
                    gridCmp.showFirstPage();
                }
                this.isSpinner = false;                            
            }
            else{
                this.error = INVOICE_LOAD_ERROR;
                this.isSpinner = false;
            }
        })
            .catch(e => this.processError(e))
            .finally(() => (this.isSpinner = false));
    }

    processError(e) {
        let {isError, error} = ErrorUtils.processError(e);
        this.error = error;
        this.isError = isError;
    }

    initTable() {
        let columns = [
            { label: LabelService.customer, fieldName: 'customerURL', type: 'url', sortable: true, initialWidth: 150,
                typeAttributes: { 
                    label: {fieldName: 'customerName'}, 
                    target: self}, 
                cellAttributes: { 
                    alignment: 'left' }},
            { label: LabelService.commonBillingNo, fieldName: 'URL', type: 'url', sortable: true, initialWidth: 150,
                typeAttributes: {
                    label: {fieldName: 'derivedName'},
                    target: self},
                cellAttributes: {
                    alignment: 'left' }},
        ];

        this.extraColumns.extraColumns.forEach(function (element) {
            columns.push(JSON.parse(element));      
        });        

        columns.push(
            { label: LabelService.commonBillingAmount, fieldName: 'total', type: 'customCurrency', sortable: true, 
                cellAttributes: {
                    alignment: 'right' },
                typeAttributes: {
                    currencyCode: { fieldName: 'currency' },
                    isMultiCurrencyEnabled: { fieldName: 'isMultiCurrencyEnabled' }}},
            { label: LabelService.commonTotalApplied, fieldName: 'applied', type: 'customCurrency', sortable: true,
                cellAttributes: {
                    alignment: 'right' },
                typeAttributes: {
                    currencyCode: { fieldName: 'currency' },
                    isMultiCurrencyEnabled: { fieldName: 'isMultiCurrencyEnabled' }}},
            { label: LabelService.commonBillingBalance, fieldName: 'balance', type: 'customCurrency', sortable: true,
                cellAttributes: {
                    alignment: 'right' },
                typeAttributes: {
                    currencyCode: { fieldName: 'currency' },
                    isMultiCurrencyEnabled: { fieldName: 'isMultiCurrencyEnabled' }}},
            { label: '', type: 'button-icon', initialWidth: 20,
                typeAttributes: {
                    name: 'apply',
                    title: LabelService.commonApply,
                    initialWidth: 20,
                    iconName: { fieldName: 'applyIcon' },
                    disabled: { fieldName: 'isClosed' }}},
            { label: LabelService.commonReceivedAmt, fieldName: 'appliedAmount', type: 'customCurrency', initialWidth: 150,
                typeAttributes: {
                    disabled: { fieldName: 'isClosed' },
                    rowId: { fieldName: 'billingId' },
                    colId: 'appliedAmount',
                    errors: { fieldName: 'errors' },
                    editMode: true}},                           
            { label: LabelService.commonAppliedDate, fieldName: 'appliedDate', type: 'customDate', initialWidth: 150,
                typeAttributes: {
                    disabled: { fieldName: 'isClosed' },
                    rowId: { fieldName: 'billingId' },
                    colId: 'appliedDate',
                    errors: { fieldName: 'errors' },
                    editMode: true}},
            { label: Labels.INF_ADJUSTMENT_AMT, fieldName: 'adjustmentAmount', type: 'customCurrency', initialWidth: 150,
                typeAttributes: {
                    disabled: { fieldName: 'isClosed' },
                    rowId: { fieldName: 'billingId' },
                    colId: 'adjustmentAmount',
                    errors: { fieldName: 'errors' },
                    editMode: true}},
            { label: LabelService.commonAdjustmentGLAcct, fieldName: 'glAccount', type: 'customLookup', initialWidth: 175,
                typeAttributes: {
                    searchObject: 'AcctSeed__GL_Account__c',
                    selectedName: { fieldName: 'glAccountName' },
                    selectedIcon: 'custom:custom3',
                    hideSelectionIcon: true,
                    disabled: { fieldName: 'isClosed' },
                    rowId: { fieldName: 'billingId' },
                    colId: 'glAccount',
                        errors: { fieldName: 'errors' }}},           
        );
        
        this.columns = columns;
    }

    filterChanged({detail}) {
        this.postingStatus = detail.postingStatus;
        this.customer = detail.customer;
        this.billingNumber = detail.billingNumber;
        this.billingDateStart = detail.billingDateStart;
        this.billingDateEnd = detail.billingDateEnd;
        this.dueDateStart = detail.dueDateStart;
        this.dueDateEnd = detail.dueDateEnd;
        this.billingAmountStart = detail.billingAmountStart;
        this.billingAmountEnd = detail.billingAmountEnd;
        this.validFilter = detail.validFilter;
    }
    
    handleCellChange({ detail }) {
        switch (detail.colId) {
            case 'appliedAmount':
                this.setCredit(detail);
                break;
            case 'adjustmentAmount':
                this.setAdjustment(detail);
                break;
            case 'appliedDate':
                this.setAppliedDate(detail);
                break;
            case 'glAccount':
                this.setGLAccount(detail);
                break;
            default:
        }
    }

    handleRowAction({ detail }) {
        switch (detail.action.name) {
            case 'apply':
                this.setMaxCredit(detail.row);
                break;
            default:
        }
    }

    handleSaveComplete() {
        this.validateAndSave(this.backToRecordHome.bind(this));
    }    

    handleSearchBillings() {
        if (this.validFilter) {
            if (this.billingStore.getChanges().length > 0) {
                this.showPopup = true;
            } else {
                this.getBillings();
            }
        }
    }

    handleSort({ detail }) { 
        this.sort(detail.fieldName, detail.sortDirection);
        this.sortOpts.sortedBy = detail.fieldName;
        this.sortOpts.sortedDirection = detail.sortDirection;
    }

    sort(field, direction) {
        if (!this.sortFactory) {
            this.sortFactory = new SortStrategyFactory(this.columns);
        }
        const sortFn = this.sortFactory.getSortStrategy(field, direction);
        this.billingStore.sort(sortFn);
        this.invoices = this.billingStore.getItems();
    }

    popupSaveEvent(){
        this.showPopup = false;
        this.getBillings();
    }
    
    popupCancelEvent(){
        this.showPopup = false;
    }

    handleSaveRefresh() {                                                                  
        this.validateAndSave(() => {
            NotificationService.displayToastMessage(this, LabelService.commonChangesSaved, LabelService.commonSaveSuccessful);
            this.error = null;
        });
    }

    handleSaveNew() {
        this.validateAndSave(() => {
            const backgroundContext = `/lightning/r/${CashReceipt.objectApiName}/${this.recordId}/view`;
            window.open(`/lightning/o/${CashReceipt.objectApiName}/new?backgroundContext=${encodeURIComponent(backgroundContext)}`, '_self');
        });
    }

    handleCancel() {
        this.backToRecordHome();
    }

    clearErrors(billingId, columnId) {
        this.billingStore.removeError(billingId, columnId);
        this.error = '';
    }

    setAppliedDate({ value: appliedDate, rowId: billingId, colId: columnId }) {
        //clear any errors off first for this column
        this.clearErrors(billingId, columnId);        
        const invoice = this.billingStore.getItem(billingId);
        const earliestAppliedDate = invoice.earliestAppliedDate;
        invoice.appliedDate = appliedDate;
        this.billingStore.updateItem(invoice);
        if (!appliedDate) {
            this.billingStore.addError(billingId, columnId, VALUE_REQUIRED);
        } else if (appliedDate < earliestAppliedDate) {
            const dateTimeFormat = new Intl.DateTimeFormat(LANG);
            const utcDate = DateUtils.toUTC(new Date(earliestAppliedDate));
            const displayDate = dateTimeFormat.format(utcDate);
            this.billingStore.addError(billingId, columnId, LabelService.errorAppliedDateMustBeGreaterThan +' '+ displayDate);
            
        } else {
            this.clearErrors(billingId, columnId);
        }
        this.invoices = this.billingStore.getItems();
    }

    setGLAccount({ value: glAccountObj, rowId: billingId, colId: columnId }) {
        //clear any errors off first for this column
        this.clearErrors(billingId, columnId);
        const invoice = this.billingStore.getItem(billingId);
        invoice.glAccount = glAccountObj != null ? glAccountObj.recordId : null;
        this.billingStore.updateItem(invoice);
        if (glAccountObj != null && !glAccountObj.recordId && invoice.adjustmentAmount > 0) {
            this.billingStore.addError(billingId, columnId, VALUE_REQUIRED);
        } else {
            this.clearErrors(billingId, columnId);         
        }
        this.setAdjustment({value: invoice.adjustmentAmount, rowId: billingId, colId: 'adjustmentAmount'});
        this.invoices = this.billingStore.getItems();
    }

    setCredit({ value: newValue = 0, rowId: billingId, colId: columnId }) {
        //clear any errors off first for this column
        this.clearErrors(billingId, columnId);
        const { appliedAmount: oldValue, balance: billingBalance } = this.billingStore.getItem(billingId);
        const maxApplicableCredit = (this.balance > billingBalance) ? billingBalance : this.balance;
        const creditDiff = parseFloat((newValue - oldValue).toFixed(5));
        if (newValue >= 0 && maxApplicableCredit >= creditDiff && newValue !== oldValue) {
            this.clearErrors(billingId, columnId);
            this.applyAmount(billingId, creditDiff);
        } else if (newValue < 0) {
            this.billingStore.addError(billingId, columnId, APPLIED_AMOUNT_LESS_THAN_ZERO);
            this.invoices = this.billingStore.getItems();
        } else if (billingBalance < creditDiff) {
            this.appliedAmount = this.appliedAmount - creditDiff;
            this.billingStore.addError(billingId, columnId, OVERAPPLIED_INVOICE);
            this.invoices = this.billingStore.getItems();
            this.applyAmount(billingId, creditDiff);
        } else if (this.balance < creditDiff) {
            this.billingStore.addError(billingId, columnId, OVERAPPLIED_CREDIT);
            this.invoices = this.billingStore.getItems();            
            this.applyAmount(billingId, creditDiff);
        } else {
            this.applyAmount(billingId, creditDiff);
            this.clearErrors(billingId, columnId);
            this.invoices = this.billingStore.getItems();
        }
    }

    setAdjustment({ value: newValue = 0, rowId: billingId, colId: columnId }) {
        //clear any errors off first for this column
        this.clearErrors(billingId, columnId);
        let rowItem = this.billingStore.getItem(billingId);
        let oldValue = rowItem.adjustmentAmount;
        let receivedAmount = rowItem.appliedAmount;
        let billingBalance = rowItem.balance;
        let glAcct = rowItem.glAccount;
        const creditDiff = parseFloat((newValue - oldValue).toFixed(5));
        if (!glAcct && newValue !== 0) {
            this.billingStore.addError(billingId, columnId, ADJUSTMENT_GL_ACCOUNT_REQUIRED);
            this.applyAdjustment(billingId, creditDiff);
        } else if (billingBalance === 0 && receivedAmount && receivedAmount > 0 && (creditDiff - billingBalance <= receivedAmount)) {
            this.clearErrors(billingId, columnId);
            this.clearErrors(billingId, 'appliedAmount');
            this.applyAdjustmentToReceivedAmount(billingId, creditDiff, false);
        } else if (billingBalance < creditDiff && (creditDiff - billingBalance <= receivedAmount)) {
            this.clearErrors(billingId, columnId);
            this.clearErrors(billingId, 'appliedAmount');
            this.applyAdjustmentToReceivedAmount(billingId, creditDiff, true);
        } else if (billingBalance < creditDiff) {
            this.billingStore.addError(billingId, columnId, OVERAPPLIED_INVOICE);
            this.applyAdjustment(billingId, creditDiff);
        } else if (newValue !== oldValue) {
            this.clearErrors(billingId, columnId);
            this.clearErrors(billingId, 'appliedAmount');
            this.applyAdjustment(billingId, creditDiff, columnId);
        } else {
            this.clearErrors(billingId, columnId);
            this.clearErrors(billingId, 'appliedAmount');
            this.invoices = this.billingStore.getItems();
        }
    }

    setMaxCredit(selectedInvoice) {
        let invoice = selectedInvoice;
        this.clearErrors(invoice.billingId, 'appliedAmount');
        this.clearErrors(invoice.billingId, 'adjustmentAmount');

        if (invoice.appliedAmount > 0) {
            const creditAmount = invoice.appliedAmount * -1;
            this.zeroOut(invoice.billingId, creditAmount);         
        } else {    
            const discount = Helper.getDiscountAmount(invoice, { receiptDate: this.receiptDate });
            const isPaidInFull = (invoice.balance - discount - this.balance) <= 0;
            if (isPaidInFull) {
                this.applyAdjustment(invoice.billingId, discount);
                invoice = this.billingStore.getItem(invoice.billingId);
            }
            const credit = (this.balance > invoice.balance) ? invoice.balance : this.balance;
            this.applyAmount(invoice.billingId, credit);
        }

        this.validateInvoice(invoice.billingId);
        this.invoices = this.billingStore.getItems();
    }

    validateInvoice(billingId) {
        const invoice = this.billingStore.getItem(billingId);
        const { ok, errors } = Helper.validateInvoice(invoice, { balance: this.balance });
        if (!ok) {
            errors.forEach(error => {
                this.billingStore.addError(billingId, error.field, error.msg);
            })
        }
    }

    zeroOut(billingId, creditAmount) {
        this.billingStore.zeroOut(billingId);
        this.invoices = this.billingStore.getItems();
        this.applied = (parseFloat(this.applied) + parseFloat(creditAmount)).toFixed(5);
    }
    
    applyAmount(billingId, creditAmount) {
        // update displayed info
        this.billingStore.applyCredit(parseFloat(creditAmount), billingId);
        this.invoices = this.billingStore.getItems();
        this.applied = (parseFloat(this.applied) + parseFloat(creditAmount)).toFixed(5);
    }

    applyAdjustmentToReceivedAmount(billingId, adjAmount, spread) {
        try {
            let item = this.billingStore.getItem(billingId);
            if (spread) {
                item.adjustmentAmount = CommonUtils.round(item.adjustmentAmount + adjAmount);
                item.appliedAmount = CommonUtils.round(item.appliedAmount - (adjAmount - item.balance));
                item.applied = CommonUtils.round(item.applied + item.balance);
                this.applied -= parseFloat(adjAmount - item.balance).toFixed(5);
                item.balance = 0;
            }
            else {
                item.adjustmentAmount = CommonUtils.round(item.adjustmentAmount + adjAmount);
                item.appliedAmount = CommonUtils.round(item.appliedAmount - adjAmount);
                if (item.appliedAmount < 0) {
                    item.balance = CommonUtils.round(item.balance - adjAmount);
                }
                this.applied -= parseFloat(adjAmount).toFixed(5);
            }

            this.billingStore.updateItem(item);
            this.invoices = this.billingStore.getItems();
        }
        catch (error) {
            console.error(error);
        }
    }

    applyAdjustment(billingId, adjustmentAmount) {
        this.billingStore.applyAdjustment(adjustmentAmount, billingId);
        this.invoices = this.billingStore.getItems();        
    }

    backToRecordHome() {
        this.navigateToViewRecordPage(this.recordId);
    }

    getDisplayData(cashReceipt) {
        return [
                {   
                    name: "column1",
                    columns: [
                        { 
                            label: LabelService.accountingHomeLedger, 
                            value: cashReceipt.AcctSeed__Ledger__r.Name, 
                            link: CommonUtils.getRecordViewPath(cashReceipt.AcctSeed__Ledger__c),
                            url: true
                        },
                        { 
                            label: LabelService.customer, 
                            value: cashReceipt.AcctSeed__Account__r.Name, 
                            link: CommonUtils.getRecordViewPath(cashReceipt.AcctSeed__Account__c),
                            url: true
                        },
                        { 
                            label: LabelService.commonType, 
                            value: cashReceipt.AcctSeed__Purpose__c,     
                            text: true                     
                        }
                    ]
                },
                {
                    name: "column2",
                    columns: [
                        {
                            label: LabelService.commonAccountingPeriod,
                            value: cashReceipt.AcctSeed__Accounting_Period__r.Name,
                            link: CommonUtils.getRecordViewPath(cashReceipt.AcctSeed__Accounting_Period__c),
                            url: true
                        },     
                        {
                            label: Labels.INF_RECEIPT_DATE,
                            value: cashReceipt.AcctSeed__Receipt_Date__c,
                            date: true
                        },       
                        {
                            label: LabelService.commonPaymentReference,
                            value: cashReceipt.AcctSeed__Payment_Reference__c,
                            text: true                     
                        }
                    ]
                }
        ];
    } 
    stringifyEach = xs => xs.map(this.stringify);
    stringify = x => JSON.stringify(x);

    translateError = error => {
        let msg;
        switch (error) {
            case 'cash_receipt_modified':
                msg = CASH_RECEIPT_MODIFIED_ERROR;
                break;
            case 'validation_failure':
                msg = LabelService.errorOccured;
                break;
            case 'save_failure':
                msg = LabelService.errorOccured;
                break;
            default:
                msg = error;
        }
        return msg;
    }
    translateErrors = errors => errors.map(this.translateError).reduce(this.errorReducer);
    errorReducer = (acc, error) => { return error ? acc + '\n' + error : acc };
    
    save(onSuccess) {
        this.isSpinner = true;
        return save({ 
            cashReceiptId: this.recordId,
            cashReceiptLastModifiedDate: this.lastModifiedDate, 
            updates: this.stringifyEach(this.billingStore.getChanges())
        }).then(result => {
            if (result.isSuccess) {
                onSuccess();
                const cashReceipt = result.cashReceipt;
                this.lastModifiedDate = cashReceipt.LastModifiedDate;
                this.name = cashReceipt.Name;            
                //this.periodStart = cashReceipt.AcctSeed__Accounting_Period__r.AcctSeed__Start_Date__c;
                this.originalApplied = cashReceipt.AcctSeed__Applied_Amount__c;
                this.originalAmount = Math.abs(cashReceipt.AcctSeed__Amount__c);
                this.originalTotal = Math.abs(cashReceipt.AcctSeed__Amount__c);
                this.receiptDate = cashReceipt.AcctSeed__Receipt_Date__c;
                //this.billingStore.setPeriodMin(this.periodStart);
                this.getBillings(false);
                this.isSpinner = false;
            } else {
                this.error = this.translateErrors(result.errors);
                this.isSpinner = false;
            }
        })
        .catch(error => {
            this.isSpinner = false;
            this.error = LabelService.commonErrorDuringSave;
            if (Array.isArray(error.body)) {
                this.error = error.body.map(e => e.message).join (', ');
            } else if (typeof error.body === 'string') {
                this.error = error.body;
            }
            
        });
    }

    getCurrencyCode(cashReceipt) {
        let isoCode = CURRENCY;
        if (this.isMultiCurrencyEnabled && cashReceipt.CurrencyIsoCode) {
            isoCode = cashReceipt.CurrencyIsoCode;
        }
        return isoCode;
    }

    validateAndSave(onSuccess) {
        if (this.isValid()) {
            return this.save(onSuccess);            
        }
        this.displayValidationErrors();
        return undefined;
    }

    isValid() {
        return !(
            this.balance < 0 
            || this.billingStore.getItems().find(item => item.errors.length > 0)
        );
    }

    displayValidationErrors() {
        const errorRowNames = this.getFieldFromErrorRows('derivedName');
        if (errorRowNames.length > 0) {
            this.displayRowLevelErrors(errorRowNames);
        } else if (this.balance < 0) {
            this.error = OVERAPPLIED_CREDIT;
        }
    }

    getFieldFromErrorRows(fieldName) {
        return this.billingStore.getItems()
            .filter(item => item.errors.length > 0)
            .map(item => item[fieldName]);
    }

    displayRowLevelErrors(errorRowNames) {
        let msg = Labels.ERR_PLEASE_CORRECT_ERROR_FOR_BILLING + ': ' + errorRowNames.reduce(this.commaReducer);
        this.error = msg;
    }

    commaReducer = (acc, rowName) => { return acc + ', ' + rowName };

}