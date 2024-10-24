import {track, api} from "lwc";
import { NavigationService, ErrorUtils, SortStrategyFactory, NotificationService, LabelService } from "c/utils";
import BankTransactionsStore from './bankTransactionsStore';
import Helper from './bankTransactionHelper';
import CURRENCY from "@salesforce/i18n/currency";
import getBankAccounts from '@salesforce/apex/BankDirectConnectHelper.getBankAccounts';
import isCashFlowStatementEnabled from '@salesforce/apex/BankDirectConnectHelper.isCashFlowStatementEnabled';
import getBankTransactions from '@salesforce/apex/BankDirectConnectHelper.getBankTransactions';
import getUnmatchedBankTransactions from '@salesforce/apex/BankDirectConnectHelper.getUnmatchedBankTransactions';
import addRecords from '@salesforce/apex/BankDirectConnectHelper.addRecords';
import matchRecords from '@salesforce/apex/BankDirectConnectHelper.matchRecords';
import unmatchRecords from '@salesforce/apex/BankDirectConnectHelper.unmatchRecords';
import applyBankRules from '@salesforce/apex/BankDirectConnectHelper.applyBankRules';
import applyAccountRules from '@salesforce/apex/BankDirectConnectHelper.applyAccountRules';
import removeRecords from '@salesforce/apex/BankDirectConnectHelper.removeRecords';
import restoreRecords from '@salesforce/apex/BankDirectConnectHelper.restoreRecords';
import fetchTransactions from '@salesforce/apex/BankDirectConnectHelper.fetchTransactions';
import TIMEZONE from "@salesforce/i18n/timeZone";
import LOCALE from "@salesforce/i18n/locale";
import Labels from "./labels";
import BDCModal from 'c/bdcModal';

const KEY_FIELD = 'Id';
const MAX_TRANSACTIONS_LOADED = 2000;
const PAGE_SIZE = 10;

export default class BdcBankCreditCardTransactions extends NavigationService {
  labels = {...LabelService, ...Labels};
  keyField = KEY_FIELD;
  pageSize = PAGE_SIZE;
  rowOffset = 0;
  sortFactory;
  unmatchedSortFactory;
  btStore = new BankTransactionsStore();
  unBtStore = new BankTransactionsStore();
  isSpinner = true;
  isError = false;
  currencyCode = CURRENCY;
  isMultiCurrencyEnabled = false;
  timezoneName = TIMEZONE;
  isCashFlowStatementEnabled = false;
  showUnmatchedTransaction = false;
  showAllTransaction = false;
  customerName;
  allUnmatchedBankTransactionsApplied = false;
  breakAllUnmatchedBankTransactionsApplied = false;
  hasRendered = false;
  isAllBTOverLimit = false;
  @track bankAccountValue = this.labels.commonNone;
  @track bankAccountNone = this.labels.commonNone;
  @track error;
  @track bankTransaction;
  @track bankTransactions = [];
  @track unmatchedBankTransactions = [];
  @track bankAccounts;
  @track filter;

  @track sortOpts = {
    sortedBy: 'bt.obj.AcctSeed__Date__c',
    sortedDirection: 'desc'
  };

  @track unmatchedSortOpts = {
    sortedBy: 'bt.obj.AcctSeed__Date__c',
    sortedDirection: 'desc'
  };

  @track bankAccount;
  unmatchedColumns = [];
  unmatchedAdditionalColumns = [];
  transactionColumns = Helper.getTransactionMainColumns();
  transactionAdditionalColumns = Helper.getTransactionAdditionalColumns();
  unmatchedTemplateName = 'c-bdc-unmatched-drawer-template';

  get bankGlAccount() {
    return {
      label: LabelService.commonBankGLAcct,
      value: this.bankAccount ? this.bankAccount.id : undefined
    };
  }

  get currency() {
    return {
      label: Labels.INF_FIA_CURRENCY,
      value: this.bankAccount ? this.bankAccount.currencyIsoCode : undefined
    };
  }

  get ledger() {
    return {
      label: LabelService.accountingHomeLedger,
      value: this.bankAccount ? this.bankAccount.id : undefined
    };
  }

  get lastRefreshedDate() {
    return {
      label: LabelService.commonLastRefreshedDate,
      value: this.bankAccount ? this.bankAccount.lastRefreshedDate : undefined,
      helpText: Labels.INF_FIA_CREDENTIALS_MFA_NEED_REFRESH_LAST_UPDATE_WITH_BANK_ACCT
    };
  }

  get currentBalance() {
    return {
      label: LabelService.commonCurrentBalance,
      value: this.bankAccount ? this.bankAccount.currentBalance : 0
    };
  }

  get availableBalance() {
    return {
      label: Labels.INF_AVAILAIBLE_BALANCE,
      value: this.bankAccount ? this.bankAccount.availableBalance : 0
    };
  }

  get showFIAStatusMessage() {
    return this.bankAccount && this.bankAccount.isFIAStatusError ? true : false;
  }

  get showMFAMessage() {
    return this.bankAccount && this.bankAccount.isMFAAccount ? true : false;
  }

  get maxInvoicesDisplayed() {
    return MAX_TRANSACTIONS_LOADED;
  }

  get bankAccountOptions() {
    if (this._bankAccountOptions === undefined) {
      this._bankAccountOptions = [{
        label: LabelService.commonNone, value: 'None'
      }];
    }
    return this._bankAccountOptions;
  }

  get downloadDisabled() {
    if (this.bankAccount) {
      return this.bankAccountValue === 'None' || this.bankAccount.isFIAStatusError ||  this.bankAccount.isMFAAccount;
    }
    return true;
  }

  @api
  refreshCreditCardPage(){
    this.unmatchedBankTransactions = [];
    this.setCashFlowStatement()
      .then(() => this.initColumns());
    this.bankAccountValue = this.labels.commonNone;
    this.bankAccountName = this.labels.commonNone;
    this.loadRecords(true, true); 
    this.template.querySelector('c-custom-data-table[data-id="unmatched-data-table"]').closeAllOpenDrawers();
  }
  
  connectedCallback() {
    this.setCashFlowStatement()
      .then(() => this.initColumns());
  }

  renderedCallback() {
    if (!this.hasRendered) {
      this.loadRecords(true, true);
      this.hasRendered = true;
    }
  }

  setCashFlowStatement() {
    return isCashFlowStatementEnabled()
      .then(result => (this.isCashFlowStatementEnabled = result));
  }

  async loadRecords(init, loadUnmatched) {
    if (init) {
      this.filter = this.defaultFilter();
      await this.loadBankAccounts();
    }
    if (loadUnmatched) {
      this.resetLoadFlags();
      this.loadFirstUnmatchedBTRecords();
    }
    this.loadBTRecords();
  }

  loadBankAccounts() {
    this.showSpinner(true);
    return getBankAccounts()
      .then(results => this.processBankAccounts(results))
      .catch(e => this.processError(e))
      .finally(() => this.showSpinner(false));
  }

  loadBTRecords() {
    this.setBTDataTableSpinner(true);
    return getBankTransactions({bankAccountId: this.currentBankAccountId(), filterBy: JSON.stringify(this.filter)})
      .then(results => this.processBTRecords(results))
      .then(() => this.resetGrid(this.bankTransactionGridCmp()))
      .catch(e => this.processError(e))
      .finally(() => this.setBTDataTableSpinner(false));
  }

  loadFirstUnmatchedBTRecords() {
    this.setUnmatchedDataTableSpinner(true);
    this.setBTDataTableSpinner(true);
    return getUnmatchedBankTransactions({bankAccountId: this.currentBankAccountId()})
      .then(results => this.processUnmatchedBTRecords(results))
      .then(() => this.applyUnmatchedBTRecords(this.rowOffset))
      .then(() => this.rowOffset = this.rowOffset + this.pageSize)
      .then(() => this.resetGrid(this.unmatchedBTGridCmp()))
      .catch(e => this.processError(e))
      .finally(() => {
        this.setBTDataTableSpinner(false);
        this.setUnmatchedDataTableSpinner(false);
        this.applyAdditionalUnmatchedBTRecords();
      });
  }

  async applyAdditionalUnmatchedBTRecords() {
    for (let i = this.rowOffset; i <= MAX_TRANSACTIONS_LOADED; i += this.pageSize) {
      if (!this.allUnmatchedBankTransactionsApplied
        && !this.breakAllUnmatchedBankTransactionsApplied
        && this.unBtStore.isRulesNotAppliedItemsByOffset(i, this.pageSize)) {
        await this.applyUnmatchedBTRecords(i);
      }
      else {
        this.allUnmatchedBankTransactionsApplied = true;
        break;
      }
    }
  }

  applyUnmatchedBTRecords(rowOffset) {
    return applyAccountRules({transactions: JSON.stringify(this.unBtStore.getItemsByOffset(rowOffset, this.pageSize))})
        .then(results => applyBankRules({transactions: JSON.stringify(results)}))
      .then(results => this.processAddAppliedBTRecords(results))
      .catch(e => this.processError(e));
  }

  resetLoadFlags() {
    this.allUnmatchedBankTransactionsApplied = false;
    this.breakAllUnmatchedBankTransactionsApplied = false;
    this.rowOffset = 0;
  }

  currentBankAccountId = () => (this.bankAccount !== undefined ? this.bankAccount.bankAccountId : null);

  handleUnmatchedItemsAction({detail}) {
    switch (detail.action.toLowerCase()) {
      case 'add':
        this.setUnmatchedDataTableSpinner(true);
        addRecords({transactionList: JSON.stringify(detail.data), bankInfo: JSON.stringify(this.bankAccount)})
          .then(results => this.processResultRecords(results, 'unmatchedItemsAction'))
          .catch(e => this.processError(e))
          .finally(() => {this.setUnmatchedDataTableSpinner(false)});
        break;
      case 'match':
        this.setUnmatchedDataTableSpinner(true);
        matchRecords({transactionList: JSON.stringify(detail.data)})
          .then(results => this.processResultRecords(results, 'unmatchedItemsAction'))
          .catch(e => this.processError(e))
          .finally(() => {this.setUnmatchedDataTableSpinner(false)});
        break;
      case 'view':
        this.setUnmatchedDataTableSpinner(false);
        break;
      default:
    }
  }

  handleBTItemsAction({detail}) {
    switch (detail.action.toLowerCase()) {
      case 'unmatch':
        this.setBTDataTableSpinner(true);
        unmatchRecords({transactionList: JSON.stringify(detail.data)})
          .then(results => this.processResultRecords(results, 'allItemsAction'))
          .catch(e => this.processError(e))
          .finally(() => {this.setBTDataTableSpinner(false)});
        break;
      case 'remove':
        this.setBTDataTableSpinner(true);
        removeRecords({transactionList: JSON.stringify(detail.data)})
          .then(results => this.processResultRecords(results, 'allItemsAction'))
          .catch(e => this.processError(e))
          .finally(() => {this.setBTDataTableSpinner(false)});
        break;
      case 'restore':
        this.setBTDataTableSpinner(true);
        restoreRecords({transactionList: JSON.stringify(detail.data)})
          .then(results => this.processResultRecords(results, 'allItemsAction'))
          .catch(e => this.processError(e))
          .finally(() => {this.setBTDataTableSpinner(false)});
        break;
      default:
    }
  }

  processBTRecords(results) {
    if (results.length > MAX_TRANSACTIONS_LOADED) {
      results.pop();
      this.isAllBTOverLimit = true;
    }
    else {
      this.isAllBTOverLimit = false;
    }
    this.btStore.setItems(results);
    this.sort(this.sortOpts.sortedBy, this.sortOpts.sortedDirection);
  }

  processAddAppliedBTRecords(results) {
    if (results.length > 0) {
      this.unBtStore.addAppliedItems(results);
      this.unmatchedSort(this.unmatchedSortOpts.sortedBy, this.unmatchedSortOpts.sortedDirection);
    }
    else {
      this.allUnmatchedBankTransactionsApplied = true;
    }
  }

  processUnmatchedBTRecords(results) {
    if (results.length > MAX_TRANSACTIONS_LOADED) {
      results.pop();
    }
    this.unBtStore.setItems(results);
    this.unmatchedSort(this.unmatchedSortOpts.sortedBy, this.unmatchedSortOpts.sortedDirection);
  }

  processResultRecords(results, context) {
    let clearUnmatchedError = context === 'allItemsAction';
    let clearError = context === 'unmatchedItemsAction';
    this.unBtStore.setUnmatchedCreatedItems(results, clearUnmatchedError);
    this.btStore.setMatchedCreatedItems(results, clearError);

    this.unmatchedSort(this.unmatchedSortOpts.sortedBy, this.unmatchedSortOpts.sortedDirection);
    this.sort(this.sortOpts.sortedBy, this.sortOpts.sortedDirection);

    if (results.some(item => item.proxyObj.obj.Id != null && item.errors.length === 0)) {
      this.displaySaveSuccess();
    }
  }

  setDefaultBankAccounts(bankAccountId) {
    if (this.bankAccounts && this.bankAccounts.length > 0) {
      this.bankAccounts.forEach((item) => {
        if (item.bankAccountId === bankAccountId) {
          this.bankAccount = item;
        }
      });
    }
  }

  processBankAccounts(data) {
    if (data.length > 0) {
      this.bankAccounts = data;
      this.bankAccount = data[0];
      this.isMultiCurrencyEnabled = data[0].isMultiCurrencyEnabled;
      this.currencyCode = data[0].currencyIsoCode;
      this._bankAccountOptions = [];
      data.map(item => {
        this._bankAccountOptions.push({ label: item.bankAccountName, value: item.bankAccountId });
        return item;
      });
      this.bankAccountValue = this._bankAccountOptions[0].value;
      this.bankAccountName = this._bankAccountOptions[0].label;
    }
  }

  handleBankAccountChange(event) {
    this.breakAllUnmatchedBankTransactionsApplied = true;
    this.setBankAccountName(event.detail.value);
    this.setDefaultBankAccounts(event.detail.value);
    this.currencyCode = this.bankAccount.currencyIsoCode;
    this.loadRecords(false, true);
  }
  setBankAccountName(value){
    let index = this._bankAccountOptions.map(function(item) { return item.value; }).indexOf(value);
    this.bankAccountName = this._bankAccountOptions[index].label;
  }
  get showDownloadButton() {
    if (this.bankAccount) {
      return this.bankAccount.source === 'Plaid';
    }
    return false;
}

  async handleDownload() {
    let bankAccount = this.bankAccounts.filter(item => {
          return item.bankAccountId === this.refs.financialInsBox.value
    });
    BDCModal.open({
      size: 'small',
      modalData: {
        header: this.labels.BDC_DOWNLOAD_TRANSACTIONS,
        body:   this.labels.BDC_TRANSACTION_MODAL_DOWNLOAD.replace('{0}', bankAccount[0].bankAccountName),
        cancelLabel: this.labels.commonNo,
        actionLabel: this.labels.commonYes
      },
      onsuccess: (e) => {
        e.stopPropagation();
        this.downloadTransactions();
      }
    });
  }

  async downloadTransactions() {
    let result;
    try {
      this.showSpinner(true);
      result = await fetchTransactions({ extId: this.refs.financialInsBox.value });
      NotificationService.displayToastMessage(this, this.labels.TRANSACTION_DOWNLOAD_PROGRESS, LabelService.commonSuccess + ':', LabelService.commonSuccess);
    }
    catch (error) {
      NotificationService.displayToastMessage(this, ErrorUtils.processError(error).error, LabelService.commonToastErrorTitle + ':', LabelService.commonErrorText);
    }
    finally {
      this.showSpinner(false);
    }
  }

  handleFilterChange({detail}) {
    this.filter = {
      ...this.filter,
      transactionType: detail.transactionType,
      status: detail.status,
      customerId: detail.customer,
      customerName: detail.customerName,
      reference: detail.reference,
      glAccount: detail.glAccount,
      glAccountName: detail.glAccountName,
      dateStart: detail.dateStart,
      dateEnd: detail.dateEnd,
      amountStart: detail.amountStart,
      amountEnd: detail.amountEnd,
      valid: detail.validFilter
    };
  }

  handleSearch() {
    if (this.filter.valid) {
      this.loadRecords(false, false);
    }
  }

  handleSort({ detail }) {
    this.sort(detail.fieldName, detail.sortDirection);
    this.sortOpts.sortedBy = detail.fieldName;
    this.sortOpts.sortedDirection = detail.sortDirection;
  }

  handleUnmatchedSort({ detail }) {
    if (this.allUnmatchedBankTransactionsApplied) {
      this.unmatchedSort(detail.fieldName, detail.sortDirection);
      this.unmatchedSortOpts.sortedBy = detail.fieldName;
      this.unmatchedSortOpts.sortedDirection = detail.sortDirection;
    }
  }

  unmatchedSort(field, direction) {
    if (!this.unmatchedSortFactory) {
      this.unmatchedSortFactory = new SortStrategyFactory(this.unmatchedColumns);
    }
    const sortFn = this.unmatchedSortFactory.getSortStrategy(field, direction);
    this.unBtStore.sort(sortFn);
    this.unmatchedBankTransactions = this.unBtStore.getItems();
    if (this.unmatchedBTGridCmp()) {
      this.unmatchedBTGridCmp().refreshView();
    }
  }

  sort(field, direction) {
    if (!this.sortFactory) {
      this.sortFactory = new SortStrategyFactory(this.transactionColumns);
    }
    const sortFn = this.sortFactory.getSortStrategy(field, direction);
    this.btStore.sort(sortFn);
    this.bankTransactions = this.btStore.getItems();
    if (this.bankTransactionGridCmp()) {
      this.bankTransactionGridCmp().refreshView();
    }
  }

  handlePageSelect({ detail }) {
    if (this.unBtStore.isRulesNotAppliedItemsByOffset(detail.offset, this.pageSize)) {
      this.applyUnmatchedBTRecords(detail.offset)
    }
  }

  processError(e) {
    let {isError, error} = ErrorUtils.processError(e);
    this.error = error;
    this.isError = isError;
  }

  showSpinner = isShown => {
    this.isSpinner = isShown;
  }

  defaultFilter = () => {
    return {
      transactionType : "All",
      status: ["All"],
      customerId: undefined,
      customerName: undefined,
      glAccountName: undefined,
      reference: undefined,
      glAccount: undefined,
      dateStart: undefined,
      dateEnd: undefined,
      amountStart: undefined,
      amountEnd: undefined,
      valid: true
    };
  }

  initColumns() {
    let columns = Helper.getUnmatchedMainColumns();
    let additionalColumns = Helper.getUnmatchedAdditionalColumns();
    if (!this.isCashFlowStatementEnabled) {
      columns = columns.filter(elem => elem.label !== 'Cash Flow Category');
      additionalColumns = additionalColumns.map(element => {
        element.columns = element.columns.filter(item => item.label !== 'Cash Flow Category');
        return element;
      });
    }
    this.unmatchedColumns = columns;
    this.unmatchedAdditionalColumns = additionalColumns;
  }

  bankTransactionGridCmp = () => this.template.querySelector(".common-table");
  unmatchedBTGridCmp = () => this.template.querySelector(".unmatched-table");

  resetGrid = (grid) => {
    if (grid) {
      grid.showFirstPage();
    }
  };

  setUnmatchedDataTableSpinner(value) {
    let element = this.unmatchedBTGridCmp();
    if (element) {
      element.showTableSpinner(value);
    }
  }

  setBTDataTableSpinner(value) {
    let element = this.bankTransactionGridCmp();
    if (element) {
        element.showTableSpinner(value);
    }
  }

  showUnmatchedActive() {
    this.showUnmatchedTransaction = true;
    this.showAllTransaction = false;
  }

  showAllActive() {
    this.showUnmatchedTransaction = false;
    this.showAllTransaction = true;
  }

  displaySaveSuccess() {
    NotificationService.displayToastMessage(this, Labels.INF_YOUR_RECORDS_CREATED, Labels.INF_CREATE_SUCCESSFUL);
  }


}