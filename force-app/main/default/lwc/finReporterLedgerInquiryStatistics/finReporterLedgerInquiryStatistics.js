import { LightningElement, wire, api, track } from "lwc";
import isMultiCurrencyEnabled from '@salesforce/apex/FinancialReporterHelper.isMultiCurrencyEnabled';
import { LabelService } from "c/utils";

export default class FinReporterLedgerInquiryStatistics extends LightningElement {

  isMultiCurrencyEnabled = false;
  labels = LabelService;
  @track
  statistic = {
    inquiryResultCount : 0,
    openingBalance : {
      value: 0,
      negativeAmount: false
    },
    inquiryAmount : {
      value: 0,
      negativeAmount: false
    },
    yearToDateBalance : {
      value: 0,
      negativeAmount: false
    },
    currencyIsoCode : '',
    hideCurrentBalance : false,
    hideOpeningBalance : false
  }

  @wire(isMultiCurrencyEnabled)
  setIsMultiCurrency({ data }) {
    if (data) {
        this.isMultiCurrencyEnabled = data;
    }
  }

  @api
  setStatisticValues(detail) {
    this.statistic.inquiryResultCount = detail.inquiryResultCount;
    this.statistic.openingBalance.value = Math.abs(detail.openingBalance);
    this.statistic.openingBalance.negativeAmount = (detail.openingBalance < 0);
    this.statistic.inquiryAmount.value = Math.abs(detail.inquiryAmount);
    this.statistic.inquiryAmount.negativeAmount = (detail.inquiryAmount < 0);
    this.statistic.yearToDateBalance.value = Math.abs(detail.yearToDateBalance);
    this.statistic.yearToDateBalance.negativeAmount = (detail.yearToDateBalance < 0);
    this.statistic.currencyIsoCode = detail.currencyIsoCode;
    this.statistic.hideCurrentBalance = detail.hideCurrentBalance;
    this.statistic.hideOpeningBalance = detail.hideOpeningBalance;
  }

  @api
  getStatisticValues() {
    return this.statistic;
  }

}