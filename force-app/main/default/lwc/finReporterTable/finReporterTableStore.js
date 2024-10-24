import { AbstractItemsStore, CommonUtils } from "c/utils";
import { FinancialReportResult } from "c/sobject";

export default class FinReporterTableStore extends AbstractItemsStore {
  idKey = 'Id';
  frr = new FinancialReportResult();

  setItems(items) {
    this.values = items
      .map(item => this.copy(item))
      .map(item => this.addDerivedFields(item));
  }

  removeItemsById(itemIds) {
    let values = this.values.map(item => this.copy(item));
    itemIds.map(item => {
      let index = values.findIndex(elem => elem.Id === item);
      if (index !== -1) {
        values.splice(index, 1);
      }
      return values;
    });
    this.values = values;
  }

  addDerivedFields = (item) => {
    let update = {...item};
    update = this.setReportNameAndLinkField(update);
    update = this.setLedgerNameAndLinkField(update);
    update = this.setBudgetLedgerNameAndLinkField(update);
    update = this.setStartPeriodNameAndLinkField(update);
    update = this.setEndPeriodNameAndLinkField(update);
    update = this.setGlavsFields(update);
    update = this.setStatusField(update);
    update = this.setCompletedDateTimeField(update);
    update = this.setCreateByNameAndLinkField(update);
    update = this.setReportDefinitionNameAndLinkField(update);
    update = this.setCurrencyField(update);
    return update;
  }

  setReportNameAndLinkField = item => {
    item.reportName = item.Name;
    if (!item.hasOwnProperty(this.frr.financial_report_definition)) {
      item.showReportName = false;
    }
    item.reportLink =
      '/lightning/cmp/' +
      FinancialReportResult.packageQualifier + 'FinancialReportViewerProxy?' +
      FinancialReportResult.packageQualifier + 'recordId=' + item.Id;

      if (item.hasOwnProperty(this.frr.status)) {
        item.showReportName = item[this.frr.status] === 'Complete';
      }
      return item;
  }

  setLedgerNameAndLinkField = item => {
    item.ledgerName = null;
    item.ledgerLink = null;
    if (item.hasOwnProperty(this.frr.ledger)) {
      item.ledgerName = CommonUtils.getDataValue(this.frr.ledger_r_name, item);
      item.ledgerLink = CommonUtils.getRecordViewPath(item[this.frr.ledger]);
    }
    return item;
  }

  setBudgetLedgerNameAndLinkField = item => {
    item.budgetLedgerName = null;
    item.budgetLedgerLink = null;
    if (item.hasOwnProperty(this.frr.budget_ledger)) {
      item.budgetLedgerName = CommonUtils.getDataValue(this.frr.budget_ledger_r_name, item);
      item.budgetLedgerLink = CommonUtils.getRecordViewPath(item[this.frr.budget_ledger]);
    }
    return item;
  }

  setStartPeriodNameAndLinkField = item => {
    item.startPeriodName = null;
    item.startPeriodLink = null;
    if (item.hasOwnProperty(this.frr.accounting_period)) {
      item.startPeriodName = CommonUtils.getDataValue(this.frr.accounting_period_r_name, item);
      item.startPeriodLink = CommonUtils.getRecordViewPath(item[this.frr.accounting_period]);
    }
    return item;
  }

  setEndPeriodNameAndLinkField = item => {
    item.endPeriodName = null;
    item.endPeriodLink = null;
    if (item.hasOwnProperty(this.frr.end_accounting_period)) {
      item.endPeriodName = CommonUtils.getDataValue(this.frr.end_accounting_period_r_name, item);
      item.endPeriodLink = CommonUtils.getRecordViewPath(item[this.frr.end_accounting_period]);
    }
    return item;
  }

  setGlavsFields = item => {
    item.glav1Name = null;
    item.glav1Link = null;
    item.glav2Name = null;
    item.glav2Link = null;
    item.glav3Name = null;
    item.glav3Link = null;
    item.glav4Name = null;
    item.glav4Link = null;
    if (item.hasOwnProperty(this.frr.gl_account_variable_1)) {
      item.glav1Name = CommonUtils.getDataValue(this.frr.gl_account_variable_1_r_name, item);
      item.glav1Link = CommonUtils.getRecordViewPath(item[this.frr.gl_account_variable_1]);
    }
    if (item.hasOwnProperty(this.frr.gl_account_variable_2)) {
      item.glav2Name = CommonUtils.getDataValue(this.frr.gl_account_variable_2_r_name, item);
      item.glav2Link = CommonUtils.getRecordViewPath(item[this.frr.gl_account_variable_2]);
    }
    if (item.hasOwnProperty(this.frr.gl_account_variable_3)) {
      item.glav3Name = CommonUtils.getDataValue(this.frr.gl_account_variable_3_r_name, item);
      item.glav3Link = CommonUtils.getRecordViewPath(item[this.frr.gl_account_variable_3]);
    }
    if (item.hasOwnProperty(this.frr.gl_account_variable_4)) {
      item.glav4Name = CommonUtils.getDataValue(this.frr.gl_account_variable_4_r_name, item);
      item.glav4Link = CommonUtils.getRecordViewPath(item[this.frr.gl_account_variable_4]);
    }
    return item;
  }

  setStatusField = item => {
    item.status = null;
    if (item.hasOwnProperty(this.frr.status)) {
      item.status = item[this.frr.status];
    }
    return item;
  }

  setCurrencyField = item => {
    item.currency = null;
    if (item.hasOwnProperty('CurrencyIsoCode')) {
      item.currency = item['CurrencyIsoCode'];
    }
    return item;
  }

  setCompletedDateTimeField = item => {
    item.completedDateTime = null;
    if (item.hasOwnProperty(this.frr.run_finished)) {
      item.completedDateTime = item[this.frr.run_finished];
    }
    return item;
  }

  setCreateByNameAndLinkField = item => {
    item.createByName = null;
    item.createByLink = null;
    if (item.hasOwnProperty(this.frr.created_by_id)) {
      item.createByName = CommonUtils.getDataValue(this.frr.created_by_id_r_name, item);
      item.createByLink = CommonUtils.getRecordViewPath(item[this.frr.created_by_id]);
    }
    return item;
  }

  setReportDefinitionNameAndLinkField = item => {
    item.reportDefinitionName = null;
    item.reportDefinitionLink = null;
    if (item.hasOwnProperty(this.frr.financial_report_definition)) {
      item.reportDefinitionName = CommonUtils.getDataValue(this.frr.financial_report_definition_r_name, item);
      item.reportDefinitionLink = CommonUtils.getRecordViewPath(item[this.frr.financial_report_definition]);
    }
    return item;
  }

}