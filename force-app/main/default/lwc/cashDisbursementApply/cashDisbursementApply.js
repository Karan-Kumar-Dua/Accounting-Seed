import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { DateUtils, SortStrategyFactory, LabelService} from "c/utils";
import PayableStore from './payableStore';
import CURRENCY from '@salesforce/i18n/currency';
import getApplicablePayables from '@salesforce/apex/CashDisbursementApplyHelper.getApplicablePayables'
import loadExtraColumns from '@salesforce/apex/CashDisbursementApplyHelper.getExtraColumns'
import loadCashDisbursement from '@salesforce/apex/CashDisbursementApplyHelper.getCashDisbursement'
import save from '@salesforce/apex/CashDisbursementApplyHelper.save';
import LANG from '@salesforce/i18n/lang';
import Labels from './labels';

const OVERAPPLIED_PAYABLE = LabelService.errorPayableBalanceCannotBeLessThanZero;
const OVERAPPLIED_CREDIT = Labels.ERR_CASH_DISBURSEMENT_BALANCE_LESS_THAN_0;
const APPLIED_AMOUNT_LESS_THAN_ZERO = LabelService.errorAppliedAmountLessThanZero;
const PAYABLE_LOAD_ERROR = Labels.ERR_LOADING_ASSOCIATED_PAYABLES;
const CASH_DISBURSEMENT_LOAD_ERROR = Labels.ERR_LOADING_CASH_DISBURSEMENT;
const CASH_DISBURSEMENT_MODIFIED_ERROR = Labels.ERR_CD_LAST_MODIFIED;
const APPLIED_DATE_TOO_EARLY = LabelService.errorAppliedDateMustBeGreaterThan + ' ';
const VALUE_REQUIRED = LabelService.commonValueReq;

const OBJECT_API_NAME = 'AcctSeed__Cash_Disbursement__c';
const KEY_FIELD = 'payableId';
const MAX_PAYABLES_LOADED = 2001;



export default class CashDisbursementApply extends NavigationMixin(LightningElement) {
    labels = {...LabelService, ...Labels};
    objectApiName = OBJECT_API_NAME;
    keyField = KEY_FIELD;
    payableStore = new PayableStore();
    sortFactory;
    provisionedRecord;
    periodStart;
    
    @api 
    set recordId(val) {
        if (val) {
            this._recordId = val;
            this.getCashDisbursement();
        }
    }
    get recordId() {
        return this._recordId;
    }

    payableRowId;
    onHoldError;
    @api payables;
    @track onHold;
    @track extraColumns;
    @track isError = false;
    @track error;
    @track isSpinner = false;    
    @track columns;
    @track name = '';
    @track disbursementDate;
    @track payeeId;
    @track payeeName;
    @track total = 0;
    @track amount = 0;
    @track applied = 0;
    @track payableNumber;
    @track payeeReference;
    @track postingStatus = "Posted";
    @track issueDateStart;
    @track issueDateEnd;
    @track dueDateStart;
    @track dueDateEnd;
    @track originalApplied;
    @track originalAmount;
    @track originalTotal;
    @track payableAmountStart;
    @track payableAmountEnd;
    @track displayData = [];
    @track validFilter;
    @track showPopup = false;
    @track currencyCode = CURRENCY;    
    @track isMultiCurrencyEnabled = false;
    @track sortOpts = {
        sortedBy: 'URL',
        sortedDirection: 'asc'
    };
        
    get balance() {
        return parseFloat(this.total || 0).toFixed(5) - parseFloat(this.applied || 0).toFixed(5);
    }

    get payableSectionTitle() {
        const totalPayables = this.payableStore.getItems().length;
        const displayMax = this.maxPayablesDisplayed;
        const displayedPayables = totalPayables > displayMax ? displayMax + '+' : totalPayables;
        return LabelService.commonPayables + ' - (' + displayedPayables + ')';
    }

    get maxPayablesDisplayed() {
        return MAX_PAYABLES_LOADED - 1;
    }

    getCashDisbursement() {
        if (!this.recordId) {
            return;
        }

        this.isSpinner = true;
        loadCashDisbursement({ cashDisbursementId: this.recordId })
        .then(data => {
            var isValid = data.isValid !== undefined ? data.isValid : true;
            this.isError = !isValid;            
            this.isMultiCurrencyEnabled = data.isMultiCurrencyEnabled;            
            this.lastModifiedDate = data.cashDisbursement.LastModifiedDate;
            this.name = data.cashDisbursement.Name;
            this.payeeId = data.cashDisbursement.AcctSeed__Payee_Id__c;
            this.payeeName = data.cashDisbursement.AcctSeed__Payee_Id__c;
            this.originalApplied = data.cashDisbursement.AcctSeed__Applied_Amount__c;
            this.originalAmount = Math.abs(data.cashDisbursement.AcctSeed__Amount__c);
            this.originalTotal = Math.abs(data.cashDisbursement.AcctSeed__Amount__c);
            this.disbursementDate = data.cashDisbursement.AcctSeed__Disbursement_Date__c;
            this.displayData = this.getDisplayData(data.cashDisbursement);  
            this.currencyCode = this.getCurrencyCode(data.cashDisbursement);
            this.payableStore.setCurrency(this.currencyCode, this.isMultiCurrencyEnabled);
            this.getExtraColumns();
            this.getPayables();
            this.error = data.validationErrors;            
        })
        .catch(() => {
            this.error = CASH_DISBURSEMENT_LOAD_ERROR;
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
        .catch(e => this.processError(e));
    }
    
    getPayables(resetSorting = true) {
        var gridCmp = this.template.querySelector(".payablesGrid");
        this.isSpinner = true;
        this.amount = this.originalAmount;
        this.applied = this.originalApplied;
        this.total = this.originalTotal;
        return getApplicablePayables({ 
            cashDisbursementId: this.recordId,
            maxPayables: MAX_PAYABLES_LOADED,
            payeeId: this.payeeId,
            postingStatus: this.postingStatus,
            payableNumber: this.payableNumber,
            payeeReference: this.payeeReference,
            issueDateStart: this.issueDateStart,
            issueDateEnd: this.issueDateEnd,
            dueDateStart: this.dueDateStart,
            dueDateEnd: this.dueDateEnd,
            payableAmountStart: this.payableAmountStart,
            payableAmountEnd: this.payableAmountEnd,
            onHold: this.onHold           
        }).then(result => {
            if (result){                
                this.payableStore.setItems(result);
                this.payables = this.payableStore.getItems(); 
                this.initTable();
                this.sort(this.sortOpts.sortedBy, this.sortOpts.sortedDirection);
                if (resetSorting && gridCmp !== null) {
                    gridCmp.showFirstPage();
                }
                this.isSpinner = false;                            
            }
            else{
                this.error = PAYABLE_LOAD_ERROR;
                this.isSpinner = false;
            }
        })
        .catch(e => this.processError(e))
        .finally(() => (this.isSpinner = false));
    }

    processError(error) {
        try {
            const errorData = JSON.parse(error.body.message);
            this.error = errorData.message;
            switch (errorData.code) {
                case 'CRUD_FLS_READ':
                    this.isError = true;
                    break;
                default:
                    this.isError = false;
            }
        } catch (e) {
            this.error = error;
        }
    }

    initTable() {
        let columns = [
            { label: LabelService.commonPayableNumber, fieldName: 'URL', type: 'url', sortable: true, initialWidth: 150,
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
            { label: LabelService.commonPayableAmount, fieldName: 'total', type: 'customCurrency', sortable: true, 
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
            { label: LabelService.commonPayableBalance, fieldName: 'balance', type: 'customCurrency', sortable: true,
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
            { label: LabelService.commonAppliedAmount, fieldName: 'appliedAmount', type: 'customCurrency', initialWidth: 150,
                typeAttributes: { 
                    disabled: { fieldName: 'isClosed' }, 
                    rowId: { fieldName: 'payableId' },
                    colId: 'appliedAmount',
                    errors: { fieldName: 'errors' },
                    editMode: true}},                           
            { label: LabelService.commonAppliedDate, fieldName: 'appliedDate', type: 'customDate', initialWidth: 150,
                typeAttributes: {
                    disabled: { fieldName: 'isClosed' },
                    rowId: { fieldName: 'payableId' },
                    colId: 'appliedDate',
                    errors: { fieldName: 'errors' },
                    editMode: true}},            
        );
        
        this.columns = columns;
    }

    filterChanged({detail}) {
        this.postingStatus = detail.postingStatus;
        this.payableNumber = detail.payableNumber;
        this.payeeReference = detail.payeeReference;
        this.issueDateStart = detail.issueDateStart;
        this.issueDateEnd = detail.issueDateEnd;
        this.dueDateStart = detail.dueDateStart;
        this.dueDateEnd = detail.dueDateEnd;
        this.payableAmountStart = detail.payableAmountStart;
        this.payableAmountEnd = detail.payableAmountEnd;
        this.validFilter = detail.validFilter;
    }
    
    handleCellChange({ detail }) {
        switch (detail.colId) {
            case 'appliedAmount':
                this.setCredit(detail);
                break;
            case 'appliedDate':
                this.setAppliedDate(detail);
                break;
            default:
        }
    }

    handleRowAction({ detail }) {
        this.payableRowId = detail.row.payableId;
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

    handleSearchPayables() {
        if (this.validFilter) {
            if (this.payableStore.getChanges().length > 0) {
                this.showPopup = true;
            } else {
                this.getPayables();
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
        this.payableStore.sort(sortFn);
        this.payables = this.payableStore.getItems();
    }

    popupSaveEvent(){
        this.showPopup = false;
        this.getPayables();
    }
    
    popupCancelEvent(){
        this.showPopup = false;
    }

    handleSaveRefresh() {                                                                  
        this.validateAndSave(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: LabelService.commonSaveSuccessful,
                message: LabelService.commonChangesSaved,
                variant: 'success'
            }));
            this.error = null;
        });
    }

    handleCancel() {
        this.backToRecordHome();
    }

    clearErrors(payableId, columnId) {
        this.payableStore.removeError(payableId, columnId);
        this.error = '';
    }

    setAppliedDate({ value: appliedDate, rowId: payableId, colId: columnId }) {
        //clear any errors off first for this column
        this.clearErrors(payableId, columnId);        
        const payable = this.payableStore.getItem(payableId);
        const earliestAppliedDate = payable.earliestAppliedDate;
        payable.appliedDate = appliedDate;
        this.payableStore.updateItem(payable);
        if (!appliedDate) {
            this.payableStore.addError(payableId, columnId, VALUE_REQUIRED);
        } else if (appliedDate < earliestAppliedDate) {
            const dateTimeFormat = new Intl.DateTimeFormat(LANG);
            const utcDate = DateUtils.toUTC(new Date(earliestAppliedDate));
            const displayDate = dateTimeFormat.format(utcDate);
            this.payableStore.addError(payableId, columnId, APPLIED_DATE_TOO_EARLY + displayDate);
            
        } else {
            this.clearErrors(payableId, columnId);
        }
        this.payables = this.payableStore.getItems();
    }

    setCredit({ value: newValue = 0, rowId: payableId, colId: columnId }) {
        //clear any errors off first for this column
        this.clearErrors(payableId, columnId);
        const { appliedAmount: oldValue, balance: payableBalance } = this.payableStore.getItem(payableId);
        const maxApplicableCredit = (this.balance > payableBalance) ? payableBalance : this.balance;
        const creditDiff = parseFloat((newValue - oldValue).toFixed(5));
        if (newValue >= 0 && maxApplicableCredit >= creditDiff && newValue !== oldValue) {
            this.clearErrors(payableId, columnId);
            this.applyAmount(payableId, creditDiff);
        } else if (newValue < 0) {
            this.payableStore.addError(payableId, columnId, APPLIED_AMOUNT_LESS_THAN_ZERO);
            this.payables = this.payableStore.getItems();
        } else if (payableBalance < creditDiff) {
            this.payableStore.addError(payableId, columnId, OVERAPPLIED_PAYABLE);
            this.payables = this.payableStore.getItems();
        } else if (parseFloat(this.balance.toFixed(5)) < creditDiff) {
            this.payableStore.addError(payableId, columnId, OVERAPPLIED_CREDIT);
            this.payables = this.payableStore.getItems();            
            this.applyAmount(payableId, creditDiff);
        } else {
            this.applyAmount(payableId, creditDiff);
            this.clearErrors(payableId, columnId);
            this.payables = this.payableStore.getItems();
        }
    }

    setMaxCredit(selectedPayable) {
        let payable = selectedPayable;
        this.clearErrors(payable.payableId, 'appliedAmount');
        
        if (payable.appliedAmount > 0) {
            const creditAmount = payable.appliedAmount * -1;
            this.zeroOut(payable.payableId, creditAmount);         
        }  else { 
            const isPaidInFull = (payable.balance - this.balance) <= 0;
            if (isPaidInFull) {
                payable = this.payableStore.getItem(payable.payableId);
            }
            const credit = (this.balance > payable.balance) ? payable.balance : this.balance;
            this.applyAmount(payable.payableId, credit);
        }
        this.validatePayable(payable.payableId);
        this.payables = this.payableStore.getItems();
    }

    validatePayable(payableId) {
        const payable = this.payableStore.getItem(payableId);
        if (payable.appliedAmount < 0) {
            this.payableStore.addError(payableId, 'appliedAmount', APPLIED_AMOUNT_LESS_THAN_ZERO);
        }
        if (payable.balance < 0) {
            this.payableStore.addError(payableId, 'appliedAmount', OVERAPPLIED_PAYABLE);            
        }
        if (this.balance < 0) {
            this.payableStore.addError(payableId, 'appliedAmount', OVERAPPLIED_CREDIT);            
        }
    }

    zeroOut(payableId, creditAmount) {
        this.payableStore.zeroOut(payableId);
        this.payables = this.payableStore.getItems();
        this.applied += creditAmount;
    }
    
    applyAmount(payableId, creditAmount) {        
        // update displayed info
        this.payableStore.applyCredit(creditAmount, payableId);
        this.payables = this.payableStore.getItems();
        this.applied += creditAmount;
    }

    backToRecordHome() { 
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.recordId,
                "actionName": "view"
            }
        });
    }

    getRecordViewPath = recordId => '/lightning/r/' + recordId + '/view';

    getDisplayData(cashDisbursement) {
        return [
                {   
                    name: "column1",
                    columns: [
                        { 
                            label: LabelService.accountingHomeLedger, 
                            value: cashDisbursement.AcctSeed__Ledger__r.Name, 
                            link: this.getRecordViewPath(cashDisbursement.AcctSeed__Ledger__c),
                            url: true
                        },
                        { 
                            label: LabelService.commonPayee, 
                            value: cashDisbursement.AcctSeed__Payee__c,
                            text: true
                            
                        },
                        { 
                            label: LabelService.commonType, 
                            value: cashDisbursement.AcctSeed__Type__c,     
                            text: true                     
                        }
                    ]
                },
                {
                    name: "column2",
                    columns: [
                        {
                            label: LabelService.commonAccountingPeriod,
                            value: cashDisbursement.AcctSeed__Accounting_Period__r.Name,
                            link: this.getRecordViewPath(cashDisbursement.AcctSeed__Accounting_Period__c),
                            url: true
                        },     
                        {
                            label: Labels.INF_DISBURSEMENT_DATE,
                            value: cashDisbursement.AcctSeed__Disbursement_Date__c,
                            date: true
                        },       
                        {
                            label: LabelService.commonPaymentReference,
                            value: cashDisbursement.AcctSeed__Reference__c,
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
            case 'cash_disbursement_modified':
                msg = CASH_DISBURSEMENT_MODIFIED_ERROR;
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
            cashDisbursementId: this.recordId,
            cashDisbursementLastModifiedDate: this.lastModifiedDate, 
            updates: this.stringifyEach(this.payableStore.getChanges())
        }).then(result => {
            if (result.isSuccess) {
                onSuccess();
                const cashDisbursement = result.cashDisbursement;
                this.lastModifiedDate = cashDisbursement.LastModifiedDate;
                this.name = cashDisbursement.Name;            
                this.originalApplied = Math.abs(cashDisbursement.AcctSeed__Applied_Amount__c);
                this.originalAmount = Math.abs(cashDisbursement.AcctSeed__Amount__c);
                this.originalTotal = Math.abs(cashDisbursement.AcctSeed__Amount__c);
                this.disbursementDate = cashDisbursement.AcctSeed__Disbursement_Date__c;
                this.getPayables(false);
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

    getCurrencyCode(cashDisbursement) {
        let isoCode = CURRENCY;
        if (this.isMultiCurrencyEnabled && cashDisbursement.CurrencyIsoCode) {
            isoCode = cashDisbursement.CurrencyIsoCode;
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
        const onHoldPayables = this.payableStore.getItems().find(payable => {
            return payable.payableId === this.payableRowId;
        });
        if(onHoldPayables !== undefined && onHoldPayables.onHold === true)
        {
            this.onHoldError = true;
            return false;
        }
        return !(
        this.balance < 0 
        || this.payableStore.getItems().find(item => item.errors.length > 0)
        );
            
    }

    displayValidationErrors() {
        const errorRowNames = this.getFieldFromErrorRows('derivedName');
        if (errorRowNames.length > 0) {
            this.displayRowLevelErrors(errorRowNames);
        } else if (this.balance < 0) {
            this.error = OVERAPPLIED_CREDIT;
        }
        else if (this.onHoldError === true ){
            this.error = Labels.ERR_CD_NOT_APPLIED_TO_PAYABLE_ON_HOLD;
        }
    }

    getFieldFromErrorRows(fieldName) {
        return this.payableStore.getItems()
            .filter(item => item.errors.length > 0)
            .map(item => item[fieldName]);
    }

    displayRowLevelErrors(errorRowNames) {
        let msg = Labels.ERR_FOR_PAYABLES + ': ' + errorRowNames.reduce(this.commaReducer);
        this.error = msg;
    }

    commaReducer = (acc, rowName) => { return acc + ', ' + rowName };

}