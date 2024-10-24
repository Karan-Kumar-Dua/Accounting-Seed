import { AbstractItemsStore, CommonUtils } from "c/utils";

export default class FinReporterLedgerInquiryTableStore extends AbstractItemsStore {
  idKey = 'Id';
  openingBalance;
  hideOpeningBalance;
  currentBalance;

  setOpeningBalance(balanceObj) {
    this.openingBalance = this.currentBalance = balanceObj.openingBalance;
    this.hideOpeningBalance = balanceObj.hideOpeningBalance;
  }

  setRunningBalance() {
    this.currentBalance = this.openingBalance;
    this.values = this.values
      .map(item => this.copy(item))
      .map(item => this.setBalanceField(item))
  }

  setItems(items) {
    this.values = items
      .map(item => this.copy(item))
      .map(item => this.addDerivedFields(item))
  }

  addDerivedFields = (item) => {
    let update = {...item};
    update = this.setTransactionNameAndLinkField(update);
    update = this.setDateField(update);
    update = this.setGlAccountNameAndLinkField(update);
    update = this.setAccountNameAndLinkField(update);
    update = this.setSourceNameAndLinkField(update);
    update = this.setPeriodNameAndLinkField(update);
    update = this.setProjectNameAndLinkField(update);
    update = this.setProjectTaskNameAndLinkField(update);
    update = this.setProductNameAndLinkField(update);
    update = this.setGlavsFields(update);
    update = this.setAmountField(update);
    return update;
  }

  setTransactionNameAndLinkField = item => {
    item.transactionName = null;
    item.transactionLink = null;
    if (item.hasOwnProperty('id')) {
      item.transactionName = this.getValue(item.id.name);
      item.transactionLink = this.getValueViewPath(item.id.id);
    }
    return item;
  }

  setDateField = item => {
    item.recordDate = null;
    if (item.hasOwnProperty('transactionDate')) {
      item.recordDate = item.transactionDate;
    }
    return item;
  }

  setGlAccountNameAndLinkField = item => {
    item.glAccountName = null;
    item.glAccountLink = null;
    if (item.hasOwnProperty('glAccount')) {
      item.glAccountName = this.getValue(item.glAccount.name);
      item.glAccountLink = this.getValueViewPath(item.glAccount.id);
    }
    return item;
  }

  setAccountNameAndLinkField = item => {
    item.accountName = null;
    item.accountLink = null;
    if (item.hasOwnProperty('account')) {
      item.accountName = this.getValue(item.account.name);
      item.accountLink = this.getValueViewPath(item.account.id);
    }
    return item;
  }

  setSourceNameAndLinkField = item => {
    item.sourceName = null;
    item.sourceLink = null;
    if (item.hasOwnProperty('source')) {
      item.sourceName = this.getValue(item.source.name);
      item.sourceLink = this.getValueViewPath(item.source.id);
    }
    return item;
  }

  setPeriodNameAndLinkField = item => {
    item.periodName = null;
    item.periodLink = null;
    if (item.hasOwnProperty('accountingPeriod')) {
      item.periodName = this.getValue(item.accountingPeriod.name);
      item.periodLink = this.getValueViewPath(item.accountingPeriod.id);
    }
    return item;
  }

  setProjectNameAndLinkField = item => {
    item.projectName = null;
    item.projectLink = null;
    if (item.hasOwnProperty('project')) {
      item.projectName = this.getValue(item.project.name);
      item.projectLink = this.getValueViewPath(item.project.id);
    }

    return item;
  }

  setProjectTaskNameAndLinkField = item => {
    item.projectTaskName = null;
    item.projectTaskLink = null;
    if (item.hasOwnProperty('projectTask')) {
      item.projectTaskName = this.getValue(item.projectTask.name);
      item.projectTaskLink = this.getValueViewPath(item.projectTask.id);
    }
    return item;
  }

  setProductNameAndLinkField = item => {
    item.productName = null;
    item.productLink = null;
    if (item.hasOwnProperty('product')) {
      item.productName = this.getValue(item.product.name);
      item.productLink = this.getValueViewPath(item.product.id);
    }
    return item;
  }

  setGlavsFields = item => {
    item.glav1Name = null;
    item.glav1Link = null;
    if (item.hasOwnProperty('glav1')) {
      item.glav1Name = this.getValue(item.glav1.name);
      item.glav1Link = this.getValueViewPath(item.glav1.id);
    }
    item.glav2Name = null;
    item.glav2Link = null;
    if (item.hasOwnProperty('glav2')) {
      item.glav2Name = this.getValue(item.glav2.name);
      item.glav2Link = this.getValueViewPath(item.glav2.id);
    }
    item.glav3Name = null;
    item.glav3Link = null;
    if (item.hasOwnProperty('glav3')) {
      item.glav3Name = this.getValue(item.glav3.name);
      item.glav3Link = this.getValueViewPath(item.glav3.id);
    }
    item.glav4Name = null;
    item.glav4Link = null;
    if (item.hasOwnProperty('glav4')) {
      item.glav4Name = this.getValue(item.glav4.name);
      item.glav4Link = this.getValueViewPath(item.glav4.id);
    }
    return item;
  }

  setAmountField = item => {
    item.totalAmount = this.getConvertedValue(item.amount);
    item.isMultiCurrencyEnabled = this.isMultiCurrencyEnabled;
    item.currency = this.currencyCode;
    item.negativeAmount = this.getNegative(item.amount);
    item.amountStyle = this.getNegativeStyle(item.negativeAmount);
    return item;
  }

  setBalanceField = item => {
    if (!this.hideOpeningBalance) {
      item.balance = this.currentBalance + item.amount;
      this.currentBalance = item.balance;
      item.negativeBalanceAmount = this.getNegative(item.balance);
      item.balanceAmountStyle = this.getNegativeStyle(item.negativeBalanceAmount);
      item.balance = this.getConvertedValue(item.balance);
    }
    return item;
  }

  getNegative = val => val >= 0 ? false : true;
  getNegativeStyle = val => val ? 'color: red' : '';
  getConvertedValue = val => val < 0 ? val * -1 : val;
  getValue = val => val === "" ? null : val;
  getValueViewPath = val => val === "" ? null : CommonUtils.getRecordViewPath(val);

}