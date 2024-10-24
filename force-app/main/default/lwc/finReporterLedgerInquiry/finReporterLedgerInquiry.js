import { LightningElement, api } from "lwc";
import Labels from './labels';
export default class FinReporterLedgerInquiry extends LightningElement {

  @api fullLabel;
  @api defaultglaccountid;
  @api defaultAcctPeriod;
  @api defaultledgerid;
  @api defaultglav1;
  @api defaultglav2;
  @api defaultglav3;
  @api defaultglav4;
  labels = Labels;
  


  handleLedgerInquiryResult(event) {
    event.stopPropagation();
    try {
      this.statistic().setStatisticValues(this.getStatistic(event.detail));
      this.table().setOpeningBalance(this.getStatistic(event.detail));
      this.table().setValues(event.detail.saveResponse.isSuccess ? event.detail.lines : []);
      this.table().setReportCriteriaOptions(this.criteria().values);
    }
    catch (error) {
      console.error(error);
    }
  }

  getStatistic(detail) {
    return {
      inquiryResultCount : detail.saveResponse.isSuccess ? detail.recordCount : 0,
      openingBalance : detail.saveResponse.isSuccess ? detail.openingBalance : 0,
      inquiryAmount : detail.saveResponse.isSuccess ? detail.reportAmount : 0,
      yearToDateBalance : detail.saveResponse.isSuccess ? detail.currentBalance : 0,
      currencyIsoCode : detail.saveResponse.isSuccess ? detail.ledgerCurrency : '',
      hideCurrentBalance : detail.saveResponse.isSuccess ? detail.hideCurrentBalance : false,
      hideOpeningBalance : detail.saveResponse.isSuccess ? detail.hideOpeningBalance : false,
    }
  }

  statistic = () => this.template.querySelector("c-fin-reporter-ledger-inquiry-statistics");
  table = () => this.template.querySelector("c-fin-reporter-ledger-inquiry-table");
  criteria = () => this.template.querySelector("c-fin-reporter-criteria-ledger-inquiry");
}