import { AbstractItemsStore, CommonUtils, DateUtils } from "c/utils";
import {
  FinancialReportResult,
  FinancialReportResultValue,
  FinancialReportRow,
  FinancialReportColumn,
  FinancialReporterSettings,
  AccountingPeriod,
  FinancialReportDefinition
} from "c/sobject";

export default class finReporterViewStore extends AbstractItemsStore {
  headers = [];
  items = [];
  settings;
  reportPeriodsByOffset;
  frResult = new FinancialReportResult();
  frrv = new FinancialReportResultValue();
  frr = new FinancialReportRow();
  frc = new FinancialReportColumn();
  frs = new FinancialReporterSettings();
  ap = new AccountingPeriod();
  frd = new FinancialReportDefinition();
  useNewDrillLink = true;
  ledgerIdMap = {};
  columnPositionToOffset = {};
  rowPositionToRowRecord = {};
  rounding = '';
  percentageDecimalPlaces = 2;
  isCustomReport = false;

  addSettings(value) {
    this.settings = value;
  }

  addItems(items) {
    this.reportPeriodsByOffset = items.reportPeriodsByOffset;
    this.rounding = items.reportResult[this.frResult.rounding] ? items.reportResult[this.frResult.rounding] : '';
    this.getPercentageDecimalPlaces(items.reportDefinition);
    this.getLedgerIdMap(items.colList);
    this.getColumnPositionToOffsetMap(items.colList);
    this.getRowPositionToRowRecord(items.rowList);
    this.getItemValuesAndLinks(items);
    this.isCustomReport = items.reportResult[this.frResult.report_type] === 'Custom Report' ? true : false;
    this.headers = this.getHeadersValues(items.reportValues);
  }

  getItemValuesAndLinks = items => {
    this.useNewDrillLink = this.isUseNewDrillLink(items);
    this.items = this.getItemsValues(items);
  }

  getItems() {
    return this.items;
  }

  getHeaders() {
    return this.headers;
  }

  getHeadersValues(reportValues) {
    let headers = reportValues.reduce((result, item) => {
      if (!Object.keys(result).includes(item[this.frrv.column_position])) {
        result[item[this.frrv.column_position]] = this.getHeaderObject(item);
      }
      return result;
    },{});

    return Object.values(headers)
  }

  getLedgerIdMap(columns) {
    this.ledgerIdMap = columns.reduce((result, item) => {
      if (!Object.keys(result).includes(item[this.frc.position])) {
        result[item[this.frc.position]] = item[this.frc.ledger];
      }
      return result;
    },{});
  }

  getColumnPositionToOffsetMap(columns) {
    this.columnPositionToOffset = columns.reduce((result, item) => {
      if (!Object.keys(result).includes(item[this.frc.position])) {
        result[item[this.frc.position]] = item[this.frc.offset];
      }
      return result;
    }, {});
  }

  getRowPositionToRowRecord(rows) {
    this.rowPositionToRowRecord = rows.reduce((result, item) => {
      if (!Object.keys(result).includes(item[this.frr.position])) {
        result[item[this.frc.position]] = item;
      }
      return result;
    }, {});
  }

  getPercentageDecimalPlaces(reportDefinition) {
    if (reportDefinition.hasOwnProperty(this.frd.percentage_decimal_places)) {
      this.percentageDecimalPlaces = reportDefinition[this.frd.percentage_decimal_places];
    }
  }

  getItemsValues(reportItems) {
    let row = 1;
    let rowCount = 1;
    let initColumnPosition = reportItems.reportValues[0][this.frrv.column_position];
    let initIndent = reportItems.reportValues[0][this.frrv.indent];
    let priorIndent = initIndent;
    let priorCalcIndent = initIndent;
    let indentMap = {};
    let rowIdsMap = {};
    let items = reportItems.reportValues.reduce((result, item, index) => {
      if (item[this.frrv.row_type] !== 'Blank') {
        if (item[this.frrv.column_position] === initColumnPosition) {
          let indent = this.getIndentValue(item, initIndent, priorIndent, priorCalcIndent, indentMap);
          let currentRowPosition = item[this.frrv.row_position];
          rowIdsMap[row] = this.getRowIdsObject(this.rowPositionToRowRecord[currentRowPosition]);
          result[row] = this.getRowObject(item, indent);
          result[row].values.push(
              this.getRowTextValue(
                  item,
                  rowIdsMap[row],
                  this.ledgerIdMap[item[this.frrv.column_position]],
                  this.columnPositionToOffset[item[this.frrv.column_position]]
              )
          );
          priorIndent = item[this.frrv.indent] + 1 - initIndent;
          priorCalcIndent = indent;
          row ++;
          rowCount ++;
          indentMap[item[this.frrv.indent]] = indent;
          if (item[this.frrv.row_type] === 'Calculation Number' && item[this.frrv.indent] === initIndent) {
            result[row] = this.getEmptyRowObject();
            result[row].values.push({value: ''});
            row ++;
            rowCount ++;
          }
        }
        else {
          if (row === rowCount) {
            row = 1;
          }
          result[row].values.push(
              this.getRowTextValue(
                  item,
                  rowIdsMap[row],
                  this.ledgerIdMap[item[this.frrv.column_position]],
                  this.columnPositionToOffset[item[this.frrv.column_position]]
              )
          );
          row ++;
          if (item[this.frrv.row_type] === 'Calculation Number' && item[this.frrv.indent] === initIndent) {
            result[row].values.push({value: ''});
            row ++;
          }
        }
      }

      return result;
    },{});

    let rows = Object.values(items);
    this.removeLastEmptyRow(rows);
    rows = this.fixLegacyReport(rows, reportItems.reportDefinition.Name);
    return rows;
  }

  removeLastEmptyRow(rows) {
    if (rows[rows.length - 1].values[0].value === '') {
      rows.pop();
    }
  }

  getIndentValue(item, initIndent, priorIndent, priorCalcIndent, indentMap) {
    let indent = ((item[this.frrv.indent] + 1) - initIndent) > 0 ? ((item[this.frrv.indent] + 1) - initIndent) : 1;
    if (indentMap.hasOwnProperty(item[this.frrv.indent])) {
      indent = indentMap[item[this.frrv.indent]];
    }
    else if (parseInt(priorCalcIndent) + 1 < indent && priorIndent < indent) {
      indent = parseInt(priorCalcIndent) + 1;
    }
    else if (parseInt(priorCalcIndent) < indent && priorIndent === indent) {
      indent = parseInt(priorCalcIndent) ;
    }
    return indent.toString();
  }

  getRowTextValue(item, rowIds, ledgerId, offset) {
    let valueObj = {value: ''};
    if (this.isPercentageValue(item) && item.hasOwnProperty(this.frrv.text_value)) {
      let val = item.hasOwnProperty(this.frrv.currency_value) ? item[this.frrv.currency_value] : 0;
      valueObj.value = `${CommonUtils.getFormattedNumber(val.toFixed(this.percentageDecimalPlaces), this.percentageDecimalPlaces)}%`;
    }
    if (!this.isPercentageValue(item) && item.hasOwnProperty(this.frrv.currency_value)) {
      valueObj.decimalValue = item[this.frrv.currency_value];
      valueObj.rounding = this.rounding;
    }
    if (this.isLinkValue(item)) {
      let periodId = this.getPeriodIdByOffset(offset);
      let periodStatus = this.getPeriodStatusByOffset(offset);
      valueObj.drill = true;
      valueObj.link =
          (this.useNewDrillLink && periodStatus !== 'Archived')
              ? this.getNewDrillLink(rowIds, ledgerId, periodId)
              : this.getOldDrillLink(rowIds, ledgerId, periodId);
    }
    return valueObj;
  };

  getFormattedHeader(item, isHeader1) {
    let header = isHeader1 ? item[this.frrv.column_header_1]: item[this.frrv.column_header_2];
    if(!this.isCustomReport){
      if (this.settings && (item[this.frrv.column_type] === 'Current Period' || item[this.frrv.column_type] === 'Year To Date')) {
        header = this.getFormattedHeaderBySetting(item, isHeader1);
      }
    }
    return header;
  }

  getFormattedHeaderBySetting(item, isHeader1) {
    let header = isHeader1 ? item[this.frrv.column_header_1]: item[this.frrv.column_header_2];
    let endDate = isHeader1 ? this.getDateFromPeriodMap(item[this.frrv.column_header_1]) : this.getDateFromPeriodMap(item[this.frrv.column_header_2]);
    switch (this.settings.settings[this.frs.column_header_variant]) {
      case 'Accounting Period':
        header = isHeader1 ? item[this.frrv.column_header_1]: item[this.frrv.column_header_2];
        break;
      case 'Period End Date':
        if (endDate) {
          endDate = endDate.replaceAll('-','/');
          header = DateUtils.getFormattedDate(endDate);
        }
        break;
      case 'MM/YY':
        if (endDate) {
          header = DateUtils.getFormattedDate(endDate, {month: '2-digit', year: 'numeric'}, 'en-US');
        }
        break;
      default:
    }
    return header;
  }

  getDateFromPeriodMap(period) {
    let result;
    Object.values(this.reportPeriodsByOffset).map(item => {
      if (period === item.Name) {
        result = item[this.ap.end_date];
      }
      return item;
    });
    return result;
  }


  getPeriodIdByOffset(offset) {
    return this.reportPeriodsByOffset[offset].Id;
  }

  getPeriodStatusByOffset(offset) {
    let currentPeriod = this.reportPeriodsByOffset[offset];
    return currentPeriod[this.ap.status];
  }

  isPercentageValue = item => item[this.frrv.column_type] === 'Calculation Percentage'
    || item[this.frrv.column_type] === 'Calculation %'
    || item[this.frrv.row_type] === 'Calculation %'
    || item[this.frrv.row_type] === 'Calculation Percentage';

  isLinkValue = item => item[this.frrv.row_type] === 'GL Account'
    && (item[this.frrv.column_type] === 'Current Period' || item[this.frrv.column_type] === 'Year To Date')
    && item[this.frrv.currency_value] !== 0
    && !item[this.frrv.suppress_cell_hyperlink];

  getRowObject = (item, indent) => {
    return {
      child: item[this.frrv.row_type] === 'GL Account' || item[this.frrv.row_type] !== 'Description' ? true : false,
      level: indent,
      calculated: item[this.frrv.row_type] === 'Calculation Number',
      values: [{value: item[this.frrv.row_label]}]
    };
  };

  getEmptyRowObject = () => {
    return {
      child: true,
      level: '1',
      values : [{value:''}]
    };
  };

  getHeaderObject = item => {
    let isHeader = item.hasOwnProperty(this.frrv.column_header_2)
      && item[this.frrv.column_header_2] !== 'period-budget-column'
      && item[this.frrv.column_header_2] !== 'calculated-budget-column';
    return {
      label: this.getFormattedHeader(item, true),
      header2: isHeader,
      label2 : isHeader ? this.getFormattedHeader(item, false) : ''
    };
  };

  getRowIdsObject = item => {
    return {
      glAccountId : item[this.frr.type] === 'GL Account' ? item[this.frr.gl_account] : '',
      glav1Id : item.hasOwnProperty(this.frr.gl_accounting_variable_1) ? item[this.frr.gl_accounting_variable_1] : '',
      glav2Id : item.hasOwnProperty(this.frr.gl_accounting_variable_2) ? item[this.frr.gl_accounting_variable_2] : '',
      glav3Id : item.hasOwnProperty(this.frr.gl_accounting_variable_3) ? item[this.frr.gl_accounting_variable_3] : '',
      glav4Id : item.hasOwnProperty(this.frr.gl_accounting_variable_4) ? item[this.frr.gl_accounting_variable_4] : '',
    };
  };

  isUseNewDrillLink = items => {
    let reportType = items.reportResult[this.frResult.report_type];
    return reportType === 'Profit & Loss'
              || reportType === 'Profit & Loss Versus Budget'
              || reportType === 'Balance Sheet'
              || reportType === 'Trial Balance'
              || reportType === 'Custom Report'
  };

  getOldDrillLink = (rowIds, ledgerId, acctPeriodId) => {
    return '/apex/'
        + FinancialReportResultValue.packageQualifier + 'FinancialReportTransactionDetail'
        + '?glAccountId=' + rowIds.glAccountId
        + '&acctPeriodId=' + acctPeriodId
        + '&ledgerId=' + ledgerId
        + '&glav1=' + rowIds.glav1Id
        + '&glav2=' + rowIds.glav2Id
        + '&glav3=' + rowIds.glav3Id
        + '&glav4=' + rowIds.glav4Id;
  };

  getNewDrillLink = (rowIds, ledgerId, acctPeriodId) => {
    return '/lightning/cmp/'
        + FinancialReportResultValue.packageQualifier + 'FinancialReporterNavProxy'
        + '?c__standardReport=ledgerInquiry'
        + '&c__ledgerId=' + ledgerId
        + '&c__glAccountId=' + rowIds.glAccountId
        + '&c__defaultAcctPeriod=' + acctPeriodId
        + '&c__defaultglav1=' + rowIds.glav1Id
        + '&c__defaultglav2=' + rowIds.glav2Id
        + '&c__defaultglav3=' + rowIds.glav3Id
        + '&c__defaultglav4=' + rowIds.glav4Id;
  };

  fixLegacyReport(rows, reportName) {
    let result;
    switch (reportName) {
      case 'Profit & Loss':
        result = this.fixLegacyProfitLossReport(rows);
        break;
      case 'Profit & Loss Versus Budget':
        result = this.fixLegacyProfitLossVsBudgetReport(rows);
        break;
      case 'Balance Sheet':
        result = this.fixLegacyBalanceSheetReport(rows);
        break;
      default:
        result = rows;
    }
    return result;
  }

  fixLegacyProfitLossReport(rows) {
    let result = [];
    rows.forEach(item => {
      if ((item.values[0].value === 'Total Revenue' || item.values[0].value === 'Total Expense') && item.level !== '1') {
        item.level = '1';
        result.push(item);
        result.push(this.addEmptyCells(this.getEmptyRowObject(), rows[0].values.length));
      }
      else {
        result.push(item);
      }

    });
    return result;
  }

  fixLegacyProfitLossVsBudgetReport(rows) {
    let result = [];
    rows.forEach(item => {
      if ((item.values[0].value === 'Total Revenue' || item.values[0].value === 'Total Expense') && item.level !== '1') {
        item.level = '1';
        result.push(item);
        result.push(this.addEmptyCells(this.getEmptyRowObject(), rows[0].values.length));
      }
      else {
        result.push(item);
      }

    });
    return result;
  }

  fixLegacyBalanceSheetReport(rows) {
    let result = [];
    rows.forEach(item => {
      if (item.values[0].value.includes('Total') && item.level === '2') {
        item.level = '1';
        result.push(item);
        result.push(this.addEmptyCells(this.getEmptyRowObject(), rows[0].values.length));
      }
      else {
        result.push(item);
      }

    });
    return result;
  }

  addEmptyCells(emptyObj, length) {
    for (let i=0; i<length-1; i++) {
      emptyObj.values.push({value: ''})
    }
    return emptyObj;
  }

}