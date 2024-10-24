import { AbstractItemsStore, CommonUtils, DateUtils, LabelService } from "c/utils";
import { BankReconciliation, CashDisbursement, CashReceipt, BankDeposit, JournalEntryLine, UnclearedBankReconciliationLine, BankDisbursement } from "c/sobject";
import Labels from "./labels";
const CLEARED_WARNING_TITLE = Labels.WRN_TRN_CLEARED_TITLE_RECONCILITION;
const VOIDED_WARNING_TITLE = Labels.WRN_TRANSACTION_VOIDED_RECONCILITION;
const LEGACY_BD_WARNING_TITLE = Labels.WRN_LEGACY_BD_MESSAGE;
const CLEARED_TITLE = LabelService.commonCleared;
const UNCLEARED_TITLE = LabelService.commonUncleared;

export default class ReconciliationItemStore extends AbstractItemsStore {
  idKey = 'Id';
  isLedgerAmount = false;
  br = new BankReconciliation();
  cd = new CashDisbursement();
  cr = new CashReceipt();
  bd = new BankDeposit();
  bankDisb = new BankDisbursement();
  ubrl = new UnclearedBankReconciliationLine();
  jel = new JournalEntryLine();
  filter;

  setMultiCurrencyEnabled(isMultiCurrencyEnabled) {
    this.isMultiCurrencyEnabled = isMultiCurrencyEnabled;
  }

  setCurrencyCode(value) {
    if (this.isMultiCurrencyEnabled ) {
      this.currencyCode = value;
    }
  }

  sortAllItemsByCleared(items, maxSize) {
    return items.sort((a,b) => this.sortByCleared(a, b)).slice(0, maxSize);
  }

  addItems(items, bankRec, viewMode) {
    let newItems = items
      .map(item => this.copy(item))
      .map(item => this.addDerivedFields(item, bankRec, viewMode));
    this.values = this.values.map(item => this.copy(item)).concat(this.getUniqItems(newItems));
  }

  updateItem(item) {
    item = this.updateReconciledIcon(item);
    super.updateItem(item);
  }

  updateItemClearedDate(idValue, dateValue) {
    let index = this.values.findIndex(elem => elem.Id === idValue);
    if (index !== -1) {
      let newItem = this.copy(this.values[index]);
      newItem.clearedDate = dateValue ? DateUtils.getFormattedDate(dateValue.replaceAll('-','/')) : 'Edit';
      newItem.rawClearedDate = dateValue;
      this.values[index] = newItem;
    }
    this.values = this.values.map(item => this.copy(item));
  }

  clearedAllItem(value, selectedItem, isMaxLoadError) {
    let result = selectedItem
      .map(item => this.copy(item))
      .map(item => this.setCleared(item, isMaxLoadError ? false : value))
      .map(item => this.updateReconciledIcon(item))
      .map(item => (isMaxLoadError ? this.disableUncleared(item) : item));
    this.setClearedItems(result);
    this.values = this.values.map(item => this.copy(item));
  }

  disableAllUnclearedItem() {
    this.values = this.values
      .map(item => this.copy(item))
      .map(item => this.disableUncleared(item));
  }

  getUniqItems(items) {
    let result = [];
    items.map(item => {
      if (!this.values.some(elem => elem.Id === item.Id)) {
        result.push(item);
      }
      return item;
    });
    return result;
  }

  getItems(filter) {
    if (filter) {
      this.filter = filter;
    }
    if (this.filter && this.filter.validFilter) {
      return this.values
        .map(item => this.copy(item))
        .filter(item => this.filterItem(item, this.filter));
    }
    return this.values;
  }

  setClearedItems(items) {
    items.map(item => {
      let index = this.values.findIndex(elem => elem.Id === item.Id);
      if (index !== -1) {
        this.values[index] = item;
      }
      return item;
    });
  }

  checkIfUnclear(items) {
    return items.some(elem => !elem.isWarning && !elem.isCleared);
  }

  filterItem = (item, filter) => {
    let isValid = true;
    if (
      !(
        !filter.searchName ||
        (item.reference && item.reference.toLowerCase().includes(filter.searchName.toLowerCase())) ||
        (item.payeeName && item.payeeName.toLowerCase().includes(filter.searchName.toLowerCase())) ||
        (item.description && item.description.toLowerCase().includes(filter.searchName.toLowerCase()))
      )
    ) {
      isValid = false;
    }
    if (filter.type && filter.type !== item.type) {
      isValid = false;
    }
    if (filter.state && filter.state !== 'All' && ((filter.state === 'Cleared' && !item.isCleared) || (filter.state === 'Uncleared' && item.isCleared))) {
      isValid = false;
    }
    if (filter.dateStart && !(filter.dateStart <= item.recordDate)) {
      isValid = false;
    }
    if (filter.dateEnd && !(filter.dateEnd >= item.recordDate)) {
      isValid = false;
    }
    if (filter.amountMin && !(filter.amountMin <= item.amount)) {
      isValid = false;
    }
    if (filter.amountMax && !(filter.amountMax >= item.amount)) {
      isValid = false;
    }
    return isValid;
  };

  sortByCleared = (a, b) => {
    if (a.hasOwnProperty(this.cd.bank_reconciliation) && !b.hasOwnProperty(this.cd.bank_reconciliation)) {
      return -1
    }
    else if (!a.hasOwnProperty(this.cd.bank_reconciliation) && b.hasOwnProperty(this.cd.bank_reconciliation)) {
      return 1
    }
    else {
      return 0
    }
  }

  disableUncleared = item => {
    if (!item.isCleared && !item.isWarning) {
      item.disableClearedButton = true;
    }
    return item;
  };

  setCleared = (item, value) => {
    let update = {...item};
    update.isCleared = value;
    return update;
  }

  addDerivedFields = (item, bankRec, viewMode) => {
    let update = {...item};
    update = this.setDateField(update);
    update = this.setClearedDateField(update);
    update = this.setReferenceField(update);
    update = this.setDescriptionField(update);
    update = this.setObjectNameAndLinkField(update);
    update = this.setPayeeNameAndLinkField(update);
    update = this.setTypeField(update, bankRec.fields[this.br.type1].value);
    update = this.setIsCleared(update, bankRec.id);
    update = this.setIsVoided(update);
    update = this.setCurrencyField(update);
    update = this.setAmountField(update, bankRec.fields[this.br.type1].value, bankRec.fields[this.br.bank_account].value);
    update = this.addReconciledIcon(update, viewMode);
    return update;
  }

  addReconciledIcon = (item, viewMode) => {
    item.disableClearedDateButton = this.getClearedDateButton(item);
    item.clearedIcon = this.getClearedIcon(item);
    item.clearedTitle = this.getClearedTitle(item);
    item.clearedButtonIcon = this.getClearedButtonIcon(item, viewMode);
    item.selectedRow = this.getSelectedRow(item, viewMode);
    return item;
  };

  updateReconciledIcon = (item, viewMode) => {
    item.disableClearedDateButton = this.getClearedDateButton(item);
    item.clearedIcon = this.getClearedIcon(item);
    item.clearedTitle = this.getClearedTitle(item);
    item.clearedButtonIcon = this.getClearedButtonIcon(item, viewMode);
    item.selectedRow = this.getSelectedRow(item, viewMode);
    return item;
  };

  getClearedDateButton = item => (item.isWarning ? true : false);

  getClearedTitle = item => {
    let title;
    if (item.isWarning) {
      title = CLEARED_WARNING_TITLE;
      if (item.isVoided) {
        title = VOIDED_WARNING_TITLE;
      }
      if (item.isLegacyBankDeposit) {
        title = LEGACY_BD_WARNING_TITLE;
      }
    }
    else {
      title = item.isCleared ? CLEARED_TITLE : UNCLEARED_TITLE;
    }
    return title;
  };

  getClearedIcon = item => {
    let icon;
    if (item.isWarning) {
      icon = 'slds-icon-standard-email-chatter';
    }
    else {
      icon = item.isCleared ? 'slds-icon-standard-approval' : '';
    }
    return icon;
  };

  getClearedButtonIcon = (item, viewMode) => {
    let icon;
    if (item.isWarning) {
      icon = 'utility:warning';
    }
    else {
      icon = item.isCleared ? 'utility:check' : (viewMode ? '' : 'utility:add');
    }
    return icon;
  };

  getSelectedRow = (item, viewMode) => (item.isCleared || viewMode ? 'slds-theme_shade' : '');

  setClass = (item, index) => (item.rowClass = index & 1 ? 'slds-theme_shade' : '');

  setIsVoided = item => {
    if ((item.hasOwnProperty(this.cd.debit_gl_account) && item[this.cd.payment_status] === 'Void') || item[this.cr.void]) {
      item.isWarning = true;
      item.isVoided = true;
    }
    return item;
  }

  setIsCleared = (item, bankRecId) => {
    item.isWarning = false;
    item.isVoided = false;
    item.isCleared = false;
    item.isLegacyBankDeposit = false;
    if (item.hasOwnProperty(this.cd.bank_reconciliation) && item[this.cd.bank_reconciliation] !== null && !this.isBRUnclearedLine(item)) {
      if (item[this.cd.bank_reconciliation] === bankRecId) {
        item.isCleared = true;
      }
      else {
        item.isWarning = true;
        item.extBRName = CommonUtils.getDataValue(this.cd.bank_reconciliation_r_name, item);
      }
    }
    if (this.isLedgerAmount && item.hasOwnProperty(this.bd.deposit_date) && !item.hasOwnProperty(this.cd.ledger_amount) && !this.isBRUnclearedLine(item)) {
      item.isWarning = true;
      item.isLegacyBankDeposit = true;
    }
    return item;
  }

  setDateField = item => {
    switch (true) {
      case item.hasOwnProperty(this.cd.disbursement_date):
        item.recordDate = item[this.cd.disbursement_date];
        break;
      case item.hasOwnProperty(this.cr.receipt_date):
        item.recordDate = item[this.cr.receipt_date];
        break;
      case item.hasOwnProperty(this.bd.deposit_date):
        item.recordDate = item[this.bd.deposit_date];
        break;
      case item.hasOwnProperty(this.jel.journal_entry):
        item.recordDate = CommonUtils.getDataValue(this.jel.journal_entry_r_journal_date, item);
        break;
      case this.isBRUnclearedLine(item):
        item.recordDate = item[this.ubrl.date];
        break;
      case item.hasOwnProperty(this.bankDisb.disbursement_date):
        item.recordDate = item[this.bankDisb.disbursement_date];
        break;
      default:
    }
    return item;
  }

  setCurrencyField = item => {
    if (this.isMultiCurrencyEnabled && item.hasOwnProperty('CurrencyIsoCode')) {
      item.currency = item.CurrencyIsoCode;
      item.isMultiCurrencyEnabled = this.isMultiCurrencyEnabled;
      if (this.isLedgerAmount) {
        item.ledgerCurrency = this.currencyCode;
      }
    }
    else {
      this.addCurrency(item)
    }
    return item;
  }

  setClearedDateField = item => {
    item.clearedDate = 'Edit';
    if (item.hasOwnProperty(this.cd.cleared_date)) {
      item.clearedDate = DateUtils.getFormattedDate(item[this.cd.cleared_date].replaceAll('-','/'));
      item.rawClearedDate = item[this.cd.cleared_date];
    }
    return item;
  }

  setReferenceField = item => {
    switch (true) {
      // CD with reference and check_number
      case item.hasOwnProperty(this.cd.reference) && item.hasOwnProperty(this.cd.check_number):
        item.reference = item[this.cd.check_number].toString() + ' - ' + item[this.cd.reference];
        break;
      // CR with payment_reference and check_number
      case item.hasOwnProperty(this.cr.payment_reference) && item.hasOwnProperty(this.cr.check_number):
        item.reference = item[this.cr.check_number].toString() + ' - ' + item[this.cr.payment_reference];
        break;
      // CR or CR with check_number. Field name is the same on both CR and CD.
      case item.hasOwnProperty(this.cd.check_number):
        item.reference = item[this.cd.check_number].toString();
        break;
      case item.hasOwnProperty(this.cr.payment_reference):
        item.reference = item[this.cr.payment_reference];
        break;
      case item.hasOwnProperty(this.bd.deposit_reference):
        item.reference = item[this.bd.deposit_reference];
        break;
      case item.hasOwnProperty(this.bankDisb.disbursement_reference):
        item.reference = item[this.bankDisb.disbursement_reference];
        break;
      case item.hasOwnProperty(this.ubrl.cash_disbursement) && item.hasOwnProperty(this.ubrl.reference) && !!CommonUtils.getDataValue(this.ubrl.cash_disbursement_r_check_number, item):
        item.reference = CommonUtils.getDataValue(this.ubrl.cash_disbursement_r_check_number, item).toString() + ' - ' + item[this.ubrl.reference];
        break;
      case item.hasOwnProperty(this.ubrl.cash_disbursement) && !!CommonUtils.getDataValue(this.ubrl.cash_disbursement_r_check_number, item):
        item.reference = CommonUtils.getDataValue(this.ubrl.cash_disbursement_r_check_number, item).toString();
        break;
      case item.hasOwnProperty(this.ubrl.cash_receipt) && item.hasOwnProperty(this.ubrl.reference) &&  !!CommonUtils.getDataValue(this.ubrl.cash_receipt_r_check_number, item):
        item.reference = CommonUtils.getDataValue(this.ubrl.cash_receipt_r_check_number, item).toString() + ' - ' + item[this.ubrl.reference];
        break;
      case item.hasOwnProperty(this.ubrl.cash_receipt) && !!CommonUtils.getDataValue(this.ubrl.cash_receipt_r_check_number, item):
        item.reference = CommonUtils.getDataValue(this.ubrl.cash_receipt_r_check_number, item).toString();
        break;
      default:
        item.reference = item[this.cd.reference];
    }
    return item;
  }

  setDescriptionField = item => {
    switch (true) {
      case item.hasOwnProperty(this.bd.deposit_reference):
        item.description = item[this.bd.deposit_reference];
        break;
      default:
        item.description = item.hasOwnProperty(this.cd.description) ? item[this.cd.description] : null;
    }
    return item;
  }

  setObjectNameAndLinkField = item => {
    if (this.isBRUnclearedLine(item)) {
      let source = this.getBRUnclearedLineSource(item)
      item.typeName = source.name;
      item.typeLink = source.link;
    }
    else {
      item.typeName = item.Name;
      item.typeLink = CommonUtils.getRecordViewPath(item.Id);
    }
    return item;
  }

  setPayeeNameAndLinkField = item => {
    switch (true) {
      case item.hasOwnProperty(this.cd.vendor) || item.hasOwnProperty(this.cd.contact) || item.hasOwnProperty(this.cd.employee) :
        if (item.hasOwnProperty(this.cd.vendor)) {
          item.payeeName = CommonUtils.getDataValue(this.cd.vendor_r_name, item);
          item.payeeLink = CommonUtils.getRecordViewPath(item[this.cd.vendor]);
        }
        else if (item.hasOwnProperty(this.cd.contact)) {
          item.payeeName = CommonUtils.getDataValue(this.cd.contact_r_name, item);
          item.payeeLink = CommonUtils.getRecordViewPath(item[this.cd.contact]);
        }
        else if (item.hasOwnProperty(this.cd.employee)) {
          item.payeeName = CommonUtils.getDataValue(this.cd.employee_r_name, item);
          item.payeeLink = CommonUtils.getRecordViewPath(item[this.cd.employee]);
        }
        break;
      case item.hasOwnProperty(this.cr.account):
        item.payeeName = CommonUtils.getDataValue(this.cr.account_r_name, item);
        item.payeeLink = CommonUtils.getRecordViewPath(item[this.cr.account]);
        break;
      case item.hasOwnProperty(this.ubrl.payee_id) && item.hasOwnProperty(this.ubrl.payee_name):
        item.payeeName = item[this.ubrl.payee_name];
        item.payeeLink = CommonUtils.getRecordViewPath(item[this.ubrl.payee_id]);
        break;
      default:
        item.payeeName = null;
        item.payeeLink = null;
    }

    return item;
  }

  setTypeField = (item, type1) => {
    let creditName = !type1 || type1 === 'Bank' ? LabelService.commonPayment : LabelService.commonCharge;
    let debitName = !type1 || type1 === 'Bank' ? LabelService.commonDeposit : LabelService.commonPayment;
    switch (true) {
      case item.hasOwnProperty(this.cd.debit_gl_account) :
        item.type = CommonUtils.getDataValue(this.cd.debit_gl_account_r_bank, item) ? Labels.INF_TRANSFER : CommonUtils.getDataValue(this.cd.amount, item) < 0 ? debitName : creditName;
        break;
      case item.hasOwnProperty(this.cr.credit_gl_account) :
        debitName = CommonUtils.getDataValue(this.cr.amount, item) < 0 ? creditName : debitName;
        item.type = CommonUtils.getDataValue(this.cr.credit_gl_account_r_bank, item) ? Labels.INF_TRANSFER : debitName;
        break;
      case item.hasOwnProperty(this.bd.deposit_date):
        item.type = CommonUtils.getDataValue(this.bd.amount, item) < 0 ? creditName : debitName
        break;
      case item.hasOwnProperty(this.bankDisb.disbursement_date):
        item.type = CommonUtils.getDataValue(this.bankDisb.amount, item) < 0 ? debitName : creditName
        break;
      case item.hasOwnProperty(this.jel.journal_entry):
        if (this.isCashIn(item)) {
          item.type = debitName;
        }
        else if (this.isCashOut(item)) {
          item.type = creditName;
        }
        break;
      case item.hasOwnProperty(this.ubrl.type) && this.isBRUnclearedLine(item):
        item.type = item[this.ubrl.type];
        break;
      default:
    }
    return item;
  }

  setAmountField = (item, type, brBankAccount) => {
    let negative = false;
    if (!type || type === 'Bank') {
      negative = this.setNegativeBankType(item, brBankAccount);
    }
    else if (type === 'Credit Card') {
      negative = this.setNegativeCreditCardType(item, brBankAccount);
    }
    this.setSign(item, negative);
    return item;
  }

  setSign = (item, negative) => {
    if (negative) {
      item.amount = item[this.cd.amount] > 0 ? (item[this.cd.amount] * -1) : item[this.cd.amount]
      if (this.isLedgerAmount) {
        item.ledgerAmount = item[this.cd.ledger_amount] > 0 ? (item[this.cd.ledger_amount] * -1) : item[this.cd.ledger_amount]
      }
    }
    else {
      item.amount = item[this.cd.amount] < 0 ? (item[this.cd.amount] * -1) : item[this.cd.amount]
      if (this.isLedgerAmount) {
        item.ledgerAmount = item[this.cd.ledger_amount] < 0 ? (item[this.cd.ledger_amount] * -1) : item[this.cd.ledger_amount]
      }
    }
  }

  setNegativeBankType = (item, brBankAccount) => {
    let negative = false;
    if (item[this.cd.amount] > 0 && ((this.isUnclearedCashOut(item) && !this.isUnclearedCashOutTransfer(item, brBankAccount)) || (this.isCashOut(item) && !this.isCashOutTransfer(item, brBankAccount)) || this.isCashInTransfer(item, brBankAccount) || this.isUnclearedCashInTransfer(item, brBankAccount))) {
      this.setNegativeStyle(item);
      negative = true;
    }
    else if (item[this.cd.amount] < 0 && ((this.isUnclearedCashIn(item) && !this.isUnclearedCashInTransfer(item, brBankAccount)) || (this.isCashIn(item) && !this.isCashInTransfer(item, brBankAccount)) || this.isCashOutTransfer(item, brBankAccount) || this.isUnclearedCashOutTransfer(item, brBankAccount))) {
      this.setNegativeStyle(item);
      negative = true;
    }
    return negative;
  }

  setNegativeCreditCardType = (item, brBankAccount) => {
    let negative = false;
    if (item[this.cd.amount] < 0 && ((this.isUnclearedCashOut(item) && !this.isUnclearedCashOutTransfer(item, brBankAccount)) || (this.isCashOut(item) && !this.isCashOutTransfer(item, brBankAccount)) || this.isCashInTransfer(item, brBankAccount) || this.isUnclearedCashInTransfer(item, brBankAccount))) {
      this.setNegativeStyle(item);
      negative = true;
    }
    else if (item[this.cd.amount] > 0 && ((this.isUnclearedCashIn(item) && !this.isUnclearedCashInTransfer(item, brBankAccount)) || (this.isCashIn(item) && !this.isCashInTransfer(item, brBankAccount)) || this.isCashOutTransfer(item, brBankAccount) || this.isUnclearedCashOutTransfer(item, brBankAccount))) {
      this.setNegativeStyle(item);
      negative = true;
    }
    return negative;
  }

  setNegativeStyle = item => (item.amountStyle = 'color: #b80707');

  isBRUnclearedLine = item => (item.hasOwnProperty(this.ubrl.date) && !item.hasOwnProperty(this.jel.journal_entry));

  getBRUnclearedLineSource = item => {
    let source = {};
    switch (true) {
      case item.hasOwnProperty(this.ubrl.bank_deposit) :
        source.name = CommonUtils.getDataValue(this.ubrl.bank_deposit_r_name, item);
        source.link = CommonUtils.getRecordViewPath(item[this.ubrl.bank_deposit]);
        break;
      case item.hasOwnProperty(this.ubrl.cash_disbursement):
        source.name = CommonUtils.getDataValue(this.ubrl.cash_disbursement_r_name, item);
        source.link = CommonUtils.getRecordViewPath(item[this.ubrl.cash_disbursement]);
        break;
      case item.hasOwnProperty(this.ubrl.cash_receipt):
        source.name = CommonUtils.getDataValue(this.ubrl.cash_receipt_r_name, item);
        source.link = CommonUtils.getRecordViewPath(item[this.ubrl.cash_receipt]);
        break;
      case item.hasOwnProperty(this.ubrl.journal_entry_line):
        source.name = CommonUtils.getDataValue(this.ubrl.journal_entry_line_r_name, item);
        source.link = CommonUtils.getRecordViewPath(item[this.ubrl.journal_entry_line]);
        break;
      default:
        source.name = null;
        source.link = null;
    }
    return source;
  }

  isUnclearedCashOut = item => {
    return this.isBRUnclearedLine(item) && (item.hasOwnProperty(this.ubrl.cash_disbursement)
      || (item.hasOwnProperty(this.ubrl.journal_entry_line) && CommonUtils.getDataValue(this.ubrl.journal_entry_line_r_credit, item)));
  }

  isUnclearedCashIn = item => {
    return this.isBRUnclearedLine(item) && (item.hasOwnProperty(this.ubrl.cash_receipt) || item.hasOwnProperty(this.ubrl.bank_deposit)
      || (item.hasOwnProperty(this.ubrl.journal_entry_line) && CommonUtils.getDataValue(this.ubrl.journal_entry_line_r_debit, item)));
  }

  isUnclearedCashOutTransfer = (item, brBankRec) => {
    return item.type === 'Transfer' && item.hasOwnProperty(this.ubrl.type) && this.isBRUnclearedLine(item) && item.hasOwnProperty(this.ubrl.cash_disbursement) && brBankRec === CommonUtils.getDataValue(this.ubrl.cash_disbursement_r_debit_gl_account, item);
  }

  isUnclearedCashInTransfer = (item, brBankRec) => {
    return item.type === 'Transfer' && item.hasOwnProperty(this.ubrl.type) && this.isBRUnclearedLine(item) && item.hasOwnProperty(this.ubrl.cash_receipt) && brBankRec === CommonUtils.getDataValue(this.ubrl.cash_receipt_r_credit_gl_account, item);
  }

  isCashOutTransfer = (item, brBankRec) => {
    return item.type === 'Transfer' && item.hasOwnProperty(this.cd.debit_gl_account) && brBankRec === item[this.cd.debit_gl_account];
  }

  isCashInTransfer = (item, brBankRec) => {
    return item.type === 'Transfer' && item.hasOwnProperty(this.cr.credit_gl_account) && brBankRec === item[this.cr.credit_gl_account];
  }

  isCashOut = item => {
    return item.hasOwnProperty(this.cd.debit_gl_account) || item.hasOwnProperty(this.jel.credit);
  }

  isCashIn = item => {
    return item.hasOwnProperty(this.cr.credit_gl_account) || item.hasOwnProperty(this.bd.deposit_date) || item.hasOwnProperty(this.jel.debit);
  }

}