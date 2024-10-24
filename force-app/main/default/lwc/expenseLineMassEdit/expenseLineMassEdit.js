import {api, track} from 'lwc';
import {NavigationService, CommonUtils, LabelService} from 'c/utils';
import saveExpenseLines from '@salesforce/apex/ExpenseReportHelper.saveExpenseLines';
import deleteExpenseLine from '@salesforce/apex/ExpenseReportHelper.deleteExpenseLine';
import Labels from './labels';

const actions = [
    {label: LabelService.commonEdit, name: 'edit'},
    {label: LabelService.commonDelete, name: 'delete'}
];

export default class ExpenseLineMassEdit extends NavigationService {
    labels = {...LabelService, ...Labels};
    @api recordId;
    @api objectApiName;
    @api editMode = false;
    @api fullScreenMode = false;
    @api expenseReportData;
    @api activeTabValue = 'expenses';

    @track expenseLinesData;
    @track expenseLinesColumns;
    @track mileageLinesData;
    @track mileageLinesColumns;
    @track dataLoaded = false;
    @track expenseLinesErrors = {};
    @track mileageLinesErrors = {};
    @track expenseLinesDraftValues = [];
    @track mileageLinesDraftValues = [];
    @track selectedRow;

    @track showNewLineDialog = false;
    @track showEditLineDialog = false;
    @track showDeleteLineDialog = false;
    @track showWarning = false;

    @track dataLoaded = false;
    @track tableLoadingState = true;

    expenseLinesDataSnapshot;
    mileageLinesDataSnapshot;
    error;

    get isMileage() {
        return (this.activeTabValue === 'mileage');
    }

    get expenseLineExists() {
        return this.expenseReportData && this.expenseReportData.expenseLines.length > 0;
    }

    get mileageLineExists() {
        return this.expenseReportData && this.expenseReportData.mileageLines.length > 0;
    }

    get showTable() {
        return this.expenseLineExists || this.mileageLineExists;
    }

    initTables() {
        //add common columns
        let commonColumns = [
            {label: LabelService.commonLine, fieldName: 'url', type: 'url', typeAttributes: { label: {fieldName: 'name'}, tooltip: {fieldName: 'name'}, target: self}},
            {label: this.expenseReportData.secureLine.project.fieldLabel, fieldName: 'project', type: 'recordName'},
            {label: this.expenseReportData.secureLine.projectTask.fieldLabel, fieldName: 'projectTask', type: 'recordName'}
        ];

        if (this.expenseReportData.secureLine.billable.isAccessible) {
            commonColumns.push(
                {label: this.expenseReportData.secureLine.billable.fieldLabel, fieldName: 'billable', type: 'boolean'}
            );
        }

        if (this.expenseReportData.secureLine.reimburse.isAccessible) {
            commonColumns.push(
                {label: this.expenseReportData.secureLine.reimburse.fieldLabel, fieldName: 'reimburse', type: 'boolean'}
            );
        }
        //add columns related to Expense Lines
        this.initExpenseLinesTable(commonColumns);
        //add columns related to Mileage Lines
        this.initMileageLinesTable(commonColumns);
        this.dataLoaded = true;
    }

    initExpenseLinesTable(commonColumns) {
        let columns = [...commonColumns];

        if (this.expenseReportData.showCreditCardVendor && this.expenseReportData.secureLine.creditCardVendor.isAccessible) {
            columns.push(
                {label: LabelService.commonCreditVendor, fieldName: 'ccVendor', type: 'recordName'}
            );
        }

        columns.push(
            {label: LabelService.commonDate, fieldName: 'date', type: 'dateCustom',
                typeAttributes: {
                    editMode: {fieldName: 'editMode'},
                    rowId: {fieldName: 'id'},
                    colId: 'date'
                }
            }
        );

        columns.push(
            {label: LabelService.commonExpenseType, fieldName: 'expenseType', type: 'recordName'}
        );

        columns.push(
            {label: LabelService.commonAmount, fieldName: 'amount', type: 'combinedAmount',
                typeAttributes: {
                    editMode: {fieldName: 'editMode'},
                    rowId: {fieldName: 'id'},
                    colId: 'amount'
                }
            }
        );

        if (this.expenseReportData.secureLine.dynamicFields.length > 0) {
            Array.prototype.push.apply(columns, this.getDynamicColumns());
        }

        if (this.editMode) {
            columns.push(
                {type: 'action', typeAttributes: {rowActions: actions, menuAlignment: 'right' }}
            );
        }

        this.expenseLinesColumns = columns;
        this.expenseLinesData = this.convertExternalData(false, this.editMode, this.expenseReportData);
        this.expenseLinesDataSnapshot = JSON.parse(JSON.stringify(this.expenseLinesData));
        this.tableLoadingState = false;
        this.dataLoaded = true;
    }

    initMileageLinesTable(commonColumns) {
        let columns = [...commonColumns];

        columns.push(
            {label: LabelService.commonDate, fieldName: 'date', type: 'dateCustom',
                typeAttributes: {
                    editMode: {fieldName: 'editMode'},
                    rowId: {fieldName: 'id'},
                    colId: 'date'
                }
            }
        );

        columns.push(
            {label: LabelService.commonExpenseType, fieldName: 'expenseType', type: 'recordName'}
        );

        if (this.expenseReportData.secureLine.mileageOrigin.isAccessible) {
            columns.push(
                {label: LabelService.commonMileageOrigin, fieldName: 'mileageOrigin', type: 'textCustom',
                    typeAttributes: {
                        editMode: {fieldName: 'editMode'},
                        rowId: {fieldName: 'id'},
                        colId: 'mileageOrigin'
                    }
                }
            );
        }
        if (this.expenseReportData.secureLine.mileageDestination.isAccessible) {
            columns.push(
                {label: LabelService.commonMileageDestination, fieldName: 'mileageDestination', type: 'textCustom',
                    typeAttributes: {
                        editMode: {fieldName: 'editMode'},
                        rowId: {fieldName: 'id'},
                        colId: 'mileageDestination'
                    }
                }
            );
        }
        if (this.expenseReportData.secureLine.miles.isAccessible) {
            columns.push(
                {label: LabelService.commonMiles, fieldName: 'miles', type: 'numberCustom',
                    typeAttributes: {
                        editMode: {fieldName: 'editMode'},
                        rowId: {fieldName: 'id'},
                        colId: 'miles',
                        mileageRate: {fieldName: 'mileageRate'}
                    }
                }
            );
        }

        columns.push(
            {label: LabelService.commonAmount, fieldName: 'amount', type: 'combinedAmount',
                typeAttributes: {
                    editMode: {fieldName: 'editMode'},
                    rowId: {fieldName: 'id'},
                    colId: 'amount'
                }
            }
        );

        if (this.expenseReportData.secureLine.dynamicFields.length > 0) {
            Array.prototype.push.apply(columns, this.getDynamicColumns());
        }

        if (this.editMode) {
            columns.push(
                {type: 'action', typeAttributes: {rowActions: actions, menuAlignment: 'right' }}
            );
        }

        this.mileageLinesColumns = columns;
        this.mileageLinesData = this.convertExternalData(true, this.editMode, this.expenseReportData);
        this.mileageLinesDataSnapshot = JSON.parse(JSON.stringify(this.mileageLinesData));
        this.tableLoadingState = false;
        this.dataLoaded = true;
    }

    convertExternalData(isMileage, isEditMode, extData) {
        let result = [];

        let lines = (isMileage) ? extData.mileageLines : extData.expenseLines;

        lines.forEach(function(element) {
            let that = this;
            let rowData = {
                editMode: isEditMode,
                id: element.id,
                url: CommonUtils.getRecordViewPath(element.id),
                name: element.name,
                project: element.project.name,
                projectTask: element.projectTask.name
            };

            rowData.billable = element.billable.booleanValue;
            rowData.reimburse = element.reimburse.booleanValue;
            rowData.ccVendor = element.creditCardVendor.name;
            rowData.date = element.lineDate.dateValue;
            rowData.expenseType = element.expenseType.name;
            rowData.mileageOrigin = element.mileageOrigin.stringValue;
            rowData.mileageDestination = element.mileageDestination.stringValue;
            rowData.miles = element.miles.decimalValue;
            rowData.mileageRate = element.mileageRate;
            rowData.amount = {
                amount: element.amount.decimalValue,
                isMileage: isMileage,
                isMultiCurrencyEnabled: extData.isMultiCurrencyEnabled,
                currency: extData.currencyIsoCode,
                internalComment: element.internalComment,
                invoiceComment: element.invoiceComment
            };

            if (element.dynamicFields.length > 0) {
                element.dynamicFields.forEach(function(dynamicFieldWrapper) {
                    rowData[dynamicFieldWrapper.fieldPath] =
                        (dynamicFieldWrapper.type === 'REFERENCE')
                            ? dynamicFieldWrapper.lookupFieldValue.name
                            : that.getDynamicPrimitiveValue(dynamicFieldWrapper)
                }, that);
            }

            result.push(rowData);
        }, this);
        return result;
    }

    getDynamicPrimitiveValue(dynamicFieldWrapper) {
        let result = null;
        if (dynamicFieldWrapper.type === 'BOOLEAN') {
            result = dynamicFieldWrapper.primitiveFieldValue.booleanValue;
        }
        if (dynamicFieldWrapper.type === 'DATE') {
            result = dynamicFieldWrapper.primitiveFieldValue.dateValue;
        }
        if (dynamicFieldWrapper.type === 'NUMBER') {
            result = dynamicFieldWrapper.primitiveFieldValue.decimalValue;
        }
        if (dynamicFieldWrapper.type === 'STRING') {
            result = dynamicFieldWrapper.primitiveFieldValue.stringValue;
        }
        return result;
    }

    getDynamicColumns() {
        let columns = [];
        this.expenseReportData.secureLine.dynamicFields.forEach(function(dynamicFieldWrapper) {
            if (dynamicFieldWrapper.type === 'REFERENCE' && dynamicFieldWrapper.lookupFieldValue.isAccessible) {
                columns.push({
                    label: dynamicFieldWrapper.label, fieldName: dynamicFieldWrapper.fieldPath, type: 'recordName'
                });
            }
            if (dynamicFieldWrapper.type === 'BOOLEAN' && dynamicFieldWrapper.primitiveFieldValue.isAccessible) {
                columns.push({
                    label: dynamicFieldWrapper.label, fieldName: dynamicFieldWrapper.fieldPath, type: 'boolean'
                });
            }
            if (dynamicFieldWrapper.type === 'DATE' && dynamicFieldWrapper.primitiveFieldValue.isAccessible) {
                columns.push({
                    label: dynamicFieldWrapper.label, fieldName: dynamicFieldWrapper.fieldPath, type: 'date'
                });
            }
            if (dynamicFieldWrapper.type === 'NUMBER' && dynamicFieldWrapper.primitiveFieldValue.isAccessible) {
                columns.push({
                    label: dynamicFieldWrapper.label, fieldName: dynamicFieldWrapper.fieldPath, type: 'number'
                });
            }
            if (dynamicFieldWrapper.type === 'STRING' && dynamicFieldWrapper.primitiveFieldValue.isAccessible) {
                columns.push({
                    label: dynamicFieldWrapper.label, fieldName: dynamicFieldWrapper.fieldPath, type: 'text'
                });
            }
        });
        return columns;
    }

    handleTabActive(event) {
        this.activeTabValue = event.target.value;
    }

    handleAddNewLine() {
        this.showNewLineDialog = true;
    }

    handleCloseDialog() {
        this.showNewLineDialog = false;
        this.showEditLineDialog = false;
        this.showDeleteLineDialog = false;
        this.showWarning = false;
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const rowId = event.detail.row.id;
        switch (action.name) {
            case 'edit':
                this.showRowDetails(rowId);
                break;
            case 'delete':
                this.showDeletePromt(rowId);
                break;
            default:
        }
    }

    showDeletePromt(rowId) {
        this.setSelectedRow(rowId);
        this.showDeleteLineDialog = true;
    }

    showRowDetails(rowId) {
        this.setSelectedRow(rowId);
        this.showEditLineDialog = true;
    }

    setSelectedRow(rowId) {
        let lines = (this.isMileage)
                            ? this.expenseReportData.mileageLines
                            : this.expenseReportData.expenseLines;

        for (let i = 0; i < lines.length; i++) {
            if (lines[i].id === rowId) {
                this.selectedRow = lines[i];
            }
        }
    }

    handleCellChange(event) {
        event.stopPropagation();
        if (this.checkEventContentIsValid(event)) {
            let colId = event.detail.colId;
            let rowId = event.detail.rowId;
            let newValue = event.detail.value;
            let isExistedUpdated = false;
            let copyDraftValues =
                (this.isMileage)
                    ? JSON.parse(JSON.stringify(this.mileageLinesDraftValues))
                    : JSON.parse(JSON.stringify(this.expenseLinesDraftValues));

            copyDraftValues.forEach(function (existedDraftValue) {
                if (existedDraftValue.id === rowId) {
                    existedDraftValue[colId] = newValue;
                    isExistedUpdated = true;
                }
            });

            if (!isExistedUpdated) {
                let newDraftValues = {};
                newDraftValues.id = rowId;
                newDraftValues[colId] = newValue;
                copyDraftValues.push(newDraftValues);
            }

            if (this.isMileage) {
                this.mileageLinesDraftValues = copyDraftValues;
            }
            else {
                this.expenseLinesDraftValues = copyDraftValues;
            }

            if (this.isMileage && colId === 'miles') {
                this.recalculateMileageAmount(rowId, newValue, event.detail.mileageRate);
            }
        }
        else {
            this.setTableErrors(event);
        }
    }

    recalculateMileageAmount(rowId, newValue, mileageRate) {
        this.mileageLinesData.forEach(function (line) {
            if (line.id === rowId) {
                line.amount.amount = newValue * mileageRate;
            }
        });
    }

    checkEventContentIsValid() {
        let result = true;
        // if (event.detail.changedCellContent[event.detail.columnId].value
        //     && (event.detail.changedCellContent[event.detail.columnId].value < 0
        //         || event.detail.changedCellContent[event.detail.columnId].value > 24)) {
        //
        //     result = false;
        // }
        //
        // if (result && this.errors.rows && this.errors.rows.hasOwnProperty(event.detail.changedCellContent.id)) {
        //     delete this.errors.rows[event.detail.changedCellContent.id];
        // }
        return result;
    }

    setTableErrors(event) {
        let rowError = this.errors.rows;
        if (!rowError) {
            rowError = {};
        }
        rowError[event.detail.changedCellContent.id] = {
            fieldNames: [event.detail.columnId]
        };
        this.errors = {rows:rowError};
    }

    handleCancel() {
        if (this.isMileage) {
            this.mileageLinesDraftValues = [];
            this.mileageLinesData = JSON.parse(JSON.stringify(this.mileageLinesDataSnapshot));
        }
        else {
            this.expenseLinesDraftValues = [];
            this.expenseLinesData = JSON.parse(JSON.stringify(this.expenseLinesDataSnapshot));
        }
    }

    handleMassUpdate() {
        this.dataLoaded = false;
        let expenseReportDataCopy = JSON.parse(JSON.stringify(this.expenseReportData));
        if (this.expenseLinesDraftValues.length > 0) {
            this.putAllChangesToLines(expenseReportDataCopy.expenseLines, this.expenseLinesDraftValues);
        }

        if (this.mileageLinesDraftValues.length > 0) {
            this.putAllChangesToLines(expenseReportDataCopy.mileageLines, this.mileageLinesDraftValues);
        }

        this.expenseReportData = expenseReportDataCopy;
        this.saveLines();
    }

    putAllChangesToLines(sourceLines, draftValues) {
        sourceLines.forEach(function (sourceLine) {
            draftValues.forEach(function (draftValue) {
                if (sourceLine.id === draftValue.id) {
                    if (draftValue.hasOwnProperty('date')) {
                        sourceLine.lineDate.dateValue = draftValue.date;
                    }
                    if (draftValue.hasOwnProperty('amount')) {
                        sourceLine.amount.decimalValue = draftValue.amount.amount;
                        sourceLine.internalComment.stringValue = draftValue.amount.internalComment.stringValue;
                        sourceLine.invoiceComment.stringValue = draftValue.amount.invoiceComment.stringValue;
                    }
                    if (draftValue.hasOwnProperty('mileageOrigin')) {
                        sourceLine.mileageOrigin.stringValue = draftValue.mileageOrigin;
                    }
                    if (draftValue.hasOwnProperty('mileageDestination')) {
                        sourceLine.mileageDestination.stringValue = draftValue.mileageDestination;
                    }
                    if (draftValue.hasOwnProperty('miles')) {
                        sourceLine.miles.decimalValue = draftValue.miles;
                    }
                }
            });
        });
    }

    saveLines() {
        //serialize lines
        let lines = [];
        this.expenseReportData.expenseLines.forEach(function (line) {
            lines.push(JSON.stringify(line));
        });
        this.expenseReportData.mileageLines.forEach(function (line) {
            lines.push(JSON.stringify(line));
        });

        saveExpenseLines({expenseReportId: this.expenseReportData.id, serializedExpenseLineWrappers: lines})
            .then(() => {
                this.error = undefined;
                this.dataLoaded = true;
                this.dispatchEvent(new CustomEvent('erltablerefresh', {detail: {operation: 'mass_update', selectedTab: this.activeTabValue}}));
            })
            .catch(error => {
                this.error = error;
                this.dataLoaded = true;
            });
    }

    handleLineDeletion() {
        deleteExpenseLine({expenseLineId: this.selectedRow.id})
            .then(() => {
                this.error = undefined;
                this.dataLoaded = true;
                this.showDeleteLineDialog = false;

                let eventData = {operation: 'line_delete', data: this.selectedRow.name};
                this.dispatchEvent(new CustomEvent('erltablerefresh', {detail: eventData, selectedTab: this.activeTabValue}));
            })
            .catch(error => {
                this.error = error;
                this.dataLoaded = true;
                this.showDeleteLineDialog = false;
            });
    }

    navigateToExpenseReport() {
        this.navigateToViewRecordPageByObject(this.recordId, this.objectApiName);
    }

    connectedCallback() {
        this.initTables();
    }
}