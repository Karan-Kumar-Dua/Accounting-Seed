import profitLoss from './columnDefinitions/profitLoss';
import profitLossVsBudget from './columnDefinitions/profitLossVsBudget';
import balanceSheet from './columnDefinitions/balanceSheet';
import trialBalance from './columnDefinitions/trialBalance';
import cashFlow from './columnDefinitions/cashFlow';
import custom from './columnDefinitions/custom';
export default class FinReporterTableHelper {

  static getColumns(reportType) {
    switch (reportType.toLowerCase()) {
      case 'profitloss': return profitLoss();
      case 'profitlossvsbudget': return profitLossVsBudget();
      case 'balancesheet': return balanceSheet();
      case 'trialbalance': return trialBalance();
      case 'cashflow': return cashFlow();
      case 'custom': return custom();
      default: return [];
    }
  }

}