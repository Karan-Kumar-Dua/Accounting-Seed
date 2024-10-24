import {track, api, wire,LightningElement} from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import {showToastMessage,idGenerator,xLabelService} from 'c/xUtils';
import getImportTemplates from '@salesforce/apex/CSVImportTemplateHelper.getImportTemplates';


export default class XDataTable extends LightningElement {

    //pagination scrolling members
    visibleRows = 10;
    @track visibledata;
    startRowIndex = 0;

    //csv modal helper map

    @track fieldsMap = {};  
    @track selectAll = false;
    swingAll = false;
    showCSVUpload=false;
    gen = idGenerator();
    @track mColumns;
    @track subGridMColumns;
   
    @api recordId;
    @api childReference;
    @api defaultSorting;
    @api intialRowCount;
    @api addRowCount = 1;
    @api keyField = 'rowKey';
    @api iconName;
    @api columns;
    @api drawer;
    @api requiredColumns;
    @api rowNumberColumn;
    @api fieldToSort;
    @api objectInfo;
    @api childObjectInfo;
    @api nameField;
    @api showCSV;
    @api showDelete;
    @api showSave;
    @api globalError;
    @api rowChangeTemplate;
    @api hasRowChangeTemplate;
    @api subquerySobjectName;
    @api subqueryRelationshipName;
    @api subGridColumns;
    @api subgridParentApiName;
    @api totalRecordsCount;
    @api hasMoreRecordsToLoad=false;
    @api ldvEnabled = false;
    
    @track selectAllProperty = new Map();
    @track actions = [];
    @track _data = [];
    @track dataToDelete = [];
    @track subgridDataToDelete = [];
    @track file;
    @track mappingObj;
    @track existingImportTemplate;
    @track subGridActions =[];
    @track subGridRowsColumns =[];
    @track fieldName;
    @track pendingAction = '';
    @track moveToPageWhenLoadCompletes = 1;
    currentSortingInfo;
    spinnerClass = 'slds-hide';
    relationshipName = '';
    dataHasErrors =false;
    undoHistory = [];
    redoHistory = [];
    subGridRecordColumns =[];

    @api refreshIfNoUnsavedChanges() {
        return this.handleRefreshEvent('refresh');
    }
    @api get recordErrors(){ return undefined;}
    set recordErrors(value){
        if(value){
            this.subgridDataToDelete = [];
            this.dataToDelete = [];
            let errorMap = new Map();
            for (let m in value.recordErrors){
                errorMap.set(m,value.recordErrors[m]);
            }  
            this._data = this._data.map( row => ({...row,
                hasError : errorMap.get(row.rowKey) ? true : row.hasError,
                message : errorMap.has(row.rowKey) ? errorMap.get(row.rowKey) : row.message}));
            
            if(this.hasSubGridDetails){
                this._data.forEach(row => {
                    row[this.subqueryRelationshipName] = row[this.subqueryRelationshipName].map( subrow => ({...subrow,
                        hasError : errorMap.get(subrow.rowKey) ? true : subrow.hasError,
                        message : errorMap.has(subrow.rowKey) ? errorMap.get(subrow.rowKey) : subrow.message}))
                    ,
                    row['childHasError'] = this.childHasError(row[this.subqueryRelationshipName])}
                );
            }
            let successMap = new Map();
            for (let m in value.successRecords){
                successMap.set(m,value.successRecords[m]);
            }
            if(successMap.size !== 0){
                value.allRecords.forEach(record => {
                    let index = this._data.map(function(item) { return item.rowKey; }).indexOf(successMap.get(record.Id));
                    if(index !== -1){
                        let tempObj = Object.assign({}, record);
                        tempObj['_row'] = Object.assign({}, tempObj);
                        tempObj['_updated'] = false;
                        tempObj['_selected'] = false;
                        tempObj['_drawer'] = this._data[index]['childHasError'];
                        tempObj['_hasSubgrid'] = this.hasSubGridDetails;
                        tempObj['rowKey'] = record.Id;
                        tempObj['childRowKeys'] = '';
                        tempObj['inEditMode'] = false;
                        tempObj['attributes'] = {type: this.childReference.split('.')[0]};
                        tempObj[this.subqueryRelationshipName] = this.checkChildRows(successMap, tempObj,this._data[index]);
                        this._data[index] = tempObj;
                    }
                })
            }
            this.calculateAllParentsChildRowKeys();
            this.visibledata = this.getVisibleData();
        }
    }
    childHasError(childs){
        let hasError = false;
        childs.forEach(item => {
            hasError = item.hasError ? true : hasError;
        });
        return hasError;
    }
    checkChildRows(successMap, record,row){
        if(this.hasSubGridDetails){
            if(record[this.subqueryRelationshipName]){
                record[this.subqueryRelationshipName].forEach(savedRow => {
                    let index = row[this.subqueryRelationshipName].map(function(item) { return item.rowKey; }).indexOf(successMap.get(savedRow.Id));
                    if(index !== -1){
                        let tempObj = Object.assign({}, savedRow);
                        tempObj['_row'] = Object.assign({}, tempObj);
                        tempObj['_updated'] = false;
                        tempObj['_selected'] = false;
                        tempObj['rowKey'] = savedRow.Id;
                        tempObj['inEditMode'] = false;
                        tempObj['attributes'] = {type: this.subquerySobjectName};
                        row[this.subqueryRelationshipName][index] = tempObj;
                    }
                })
            }
            return row[this.subqueryRelationshipName];
        }
        return null;
    }
    @api get tableData(){
        return this._data;
    }
    set tableData(value){
        if(value){
            this.prepareData(value);
            this.visibledata = this.getVisibleData();
        }
    }
    prepareData(value){
        if(value.length > 0){
            if(this.rowNumberColumn && Object.keys(this.rowNumberColumn).length !== 0){
                value = this.manageRowOrders(JSON.parse(JSON.stringify(value)));
            }
            this._data = value.map(row => ({ ...row, _row: row, _updated: row['_updated'] ? row['_updated'] : false, _selected: false, _drawer: false,_hasSubgrid:false,childRowKeys : '', rowKey: row['Id'], attributes: { type: this.childReference.split('.')[0] } }));
            this.setSubGridKeys();
            this.calculateAllParentsChildRowKeys();
            this.setIntialValues();
            if(this.currentSortingInfo && Object.keys(this.currentSortingInfo).length > 0){
                this.sortTable();
            }else if(this.fieldToSort){
                this.columns.forEach(item => {
                    if(item.apiName === this.fieldToSort){
                        this.currentSortingInfo = this.item;
                    }
                });
                if(this.currentSortingInfo && Object.keys(this.currentSortingInfo).length > 0){
                    this.sortTable();
                }
            }
            this.manageActionButtonsVisibility();
            this.handlePendingActions();
        }else{
            this.intialRowCount = this.intialRowCount || 1;
            this._data = [];
            this.dispatchEvent(new CustomEvent('addrow', { detail: {lines : this._data, isLoad : true} }));
        }
    }
    handlePendingActions(){
        if(this._data.length === this.totalRecordsCount){
            if(this.pendingAction === 'csv'){
                this.fireActionEvent(this.pendingAction,this._data,[],[]);
            }else if(this.pendingAction === 'addrow'){
                this.fireAddrowEvent();
            }else if(this.pendingAction === 'pageChange'){
                this.startRowIndex = this.moveToPageWhenLoadCompletes;
                this.visibledata = this._data.slice(this.startRowIndex, this.startRowIndex + this.visibleRows);
                this.selectAll = this.selectAllProperty.get((this.startRowIndex/this.visibleRows));
            }
            this.pendingAction = '';
            this.moveToPageWhenLoadCompletes = 1;
        }
    }
    fireAddrowEvent(){
        this.dispatchEvent(new CustomEvent('addrow', { detail: {lines : this._data, isLoad : false} }));
    }
    setSubGridKeys(){
        if(this.hasSubGridDetails){
            let tempData = Object.assign([],this._data);
            tempData.forEach(row => {
                    row['_hasSubgrid'] = true,
                    row[this.subqueryRelationshipName] = row[this.subqueryRelationshipName] || [{}],
                    row[this.subqueryRelationshipName] = row[this.subqueryRelationshipName].map(subrow => 
                    subrow = this.getSubrowWithDefaultData(subrow,row)
                )}
            );
            this._data = tempData;
        }
    }
    getSubrowWithDefaultData(subrow,row){
        let key = this.gen.next().value;
        let tempRow = Object.assign({},subrow);
        tempRow['_selected'] = false;
        tempRow['_updated'] = false;
        tempRow['inEditMode'] = subrow.Id ? false : true;
        tempRow['rowKey'] = key;
        tempRow['attributes'] = { type: this.subquerySobjectName };
        tempRow[this.subgridParentApiName] = row.Id || null;
        tempRow['_row'] = Object.assign({},tempRow);
        return tempRow;
    }
    get hasSubGridDetails(){
        return (this.subqueryRelationshipName !== null && this.subqueryRelationshipName !== undefined && this.subqueryRelationshipName !== '' &&
                this.subquerySobjectName !== null && this.subquerySobjectName !== undefined && this.subquerySobjectName !== '');
    }
    handleLoadRows(rows) {
        const isDrawer = true;
        this._data = [];
        rows.forEach((item,index) => {
            let newRow = this.getRowWithExtraKeys(item);
            if (this.rowNumberColumn && Object.keys(this.rowNumberColumn).length !== 0) {
                newRow[this.rowNumberColumn.apiName] = index + 1;
            }
            newRow = this.setSubQueryRecordDetails(newRow);
            newRow['_drawer'] = isDrawer;
            newRow['_hasSubgrid'] = this.hasSubGridDetails;
            newRow['childRowKeys'] = '';
            this._data.push(newRow);
        });
        this.swingAll = isDrawer;
        this.setSubGridKeys();
        this.calculateAllParentsChildRowKeys();
        this.setIntialValues();
        this.manageActionButtonsVisibility();
    }
    setSubQueryRecordDetails(newRow){
        if(this.hasSubGridDetails){
            if(!newRow[this.subqueryRelationshipName]){
                newRow[this.subqueryRelationshipName] = [{}];
            }
        }
        return newRow;
    }
    setIntialValues() {
        this.intialValues();
        this.init();
    }
    manageActionButtonsVisibility() {
        this.manageActionButtons();
        this.manageSubgridActionButtons();
        this.disableEnableActionButton('save',true);
        this.spinnerClass = 'slds-hide';
    }
    manageRowOrders(value){
        if(!this.rowNumberColumn){return value;}
        let fName = this.rowNumberColumn.apiName;
        value.sort(function(a, b){
            return a[fName] - b[fName];
        });
        let currentIndex = 0;
        let copyOfValue = JSON.parse(JSON.stringify(value));
        copyOfValue.forEach(item => {
            if(item[fName] === null || item[fName] === undefined || item[fName] === ''){
                item[fName] = ++currentIndex;
                item['_updated'] = true;
            }else{
                currentIndex = item[fName];
            }
        });
        copyOfValue.sort(function(a, b){
            return a[fName] - b[fName];
        });
        value = copyOfValue;
        return value;
    }
    init() {
        this.manageDefaultSorting();
        let totalPages = Math.max(Math.ceil(this._data.length/this.visibleRows), 1) - 1;
        for(let i = 0; i <= totalPages; i++){
            this.selectAllProperty.set(i,false);
        }
        this.visibledata = this.getVisibleData();
    }
    manageDefaultSorting(){
        this.setmColumns();
        let self = this;
        if(!this.fieldToSort){return;}
        let splitCols = this.fieldToSort.split('.');
        this._data.sort(function(a, b){
            let first = splitCols.length > 1 ? (a[splitCols[0]] ? a[splitCols[0]][splitCols[1]] : null)
                                             : a[splitCols[0]] ? 
                                             splitCols.length > 1 ?
                                             (a[splitCols[0]] ? a[splitCols[0]][splitCols[1]] : '')
                                             : a[splitCols[0]] : '',
                second = splitCols.length > 1 ? (b[splitCols[0]] ? b[splitCols[0]][splitCols[1]] : null)
                                            : b[splitCols[0]] ? 
                                            splitCols.length > 1 ?
                                            (b[splitCols[0]] ? b[splitCols[0]][splitCols[1]] : '')
                                            : b[splitCols[0]] : '';
            if(self.defaultSorting === 'ASC' || self.defaultSorting === ''){
                return self.sortHelper(self.mColumns.get(splitCols[0]) ? self.mColumns.get(splitCols[0]).type : 'text',first,second);
            }else{
                return self.sortHelper(self.mColumns.get(splitCols[0]) ? self.mColumns.get(splitCols[0]).type : 'text',second,first);
            }
        });
    }
    getVisibleData(fromAdd=false) {
        let endIndex;
        let startIndex;
        if(fromAdd === true){
            endIndex = this._data.length > (this.startRowIndex + this.visibleRows) ? this._data.length : this.startRowIndex + this.visibleRows;
            startIndex = this._data.length > (this.startRowIndex + this.visibleRows) ?  this.startRowIndex + this.visibleRows : this.startRowIndex;
        }
        else{
            endIndex = (this.startRowIndex + this.visibleRows) >= this._data.length ? this._data.length : this.startRowIndex + this.visibleRows;
            startIndex = this.startRowIndex;
        }
        return this._data.slice(startIndex, endIndex);
    }
    get hasDrawerFields(){
        return ((this.drawer && this.drawer.length > 0) || this.hasSubGridDetails) ? true : false;
    }
    manageActionButtons(){
        let actionData = [{icon:'utility:add',name:'add',label:xLabelService.addRow, isButton :true, title : xLabelService.addRow}];
        if(this.showSave)
            actionData.push({icon:'utility:save',name:'save',label:xLabelService.commonSave, isButton :true, title : xLabelService.commonSave});
        actionData.push({icon:'utility:refresh',name:'refresh',label:xLabelService.commonRefresh, isButton :false, title : xLabelService.commonRefresh});
        if (this.showCSV) {
            actionData.push({icon:'utility:upload',name:'csvupload',label:xLabelService.csvUpload, isButton :true, title : xLabelService.importCsv});
            actionData.push({icon:'utility:download',name:'csv',label:xLabelService.csv, isButton :true, title : xLabelService.exportCsv});      
        }
        if(this.showDelete)
            actionData.push({icon:'utility:delete',name:'delete',label:xLabelService.commonDelete, isButton :true, title : xLabelService.commonDelete});
        actionData.push({icon:'utility:undo',name:'undo',label:xLabelService.commonUndo, isButton :false, title : xLabelService.commonUndo});
        actionData.push({ icon: 'utility:redo', name: 'redo', label: xLabelService.commonRedo, isButton: false, title: xLabelService.commonRedo});
        this.actions = this.createActions(actionData);
    }
    manageSubgridActionButtons(){
        let actionData = [{icon:'utility:add',name:'add',label:xLabelService.addRow, isButton :true, title : xLabelService.addRow},
            {icon:'utility:delete',name:'delete',label:xLabelService.commonDelete, isButton :true, title : xLabelService.commonDelete}];
        this.subGridActions = actionData;
    }
    createActions(actionData){
        let tempActions = [];
        actionData.forEach(item => {
            tempActions.push({
                icon: item.icon,
                name: item.name,
                label: item.label,
                title: item.title,
                variant: "border-filled",
                alternativeText: item.label,
                global: item.name === 'delete' ? false :true,
                isButton : item.isButton,
                disabled : false
            })
        });
        return tempActions;
    }
    get hasRecordsForPagination(){
        return this._data ? this._data.length > this.visibleRows : false;
    }

    intialValues(){
        this.dataToDelete = [];
        this.undoHistory = [];
        this.redoHistory = [];
        this.subgridDataToDelete = [];
    }

    @wire(getRecord, { recordId: '$recordId', fields : '$nameField'})
    recordInfo;

    get rowLevelAction(){
        return [{label:xLabelService.commonCopy,value:'copy'},{label:xLabelService.commonEdit,value:'edit'},
                {label:xLabelService.commonDelete,value:'delete'}];
    }
    get objectLabel(){
        return this.childObjectInfo.data
            ? this.childObjectInfo.data.labelPlural
            : '';
    }
    get renderTable(){
        return this.visibledata ? true : false;
    }
    get cancelText(){
        return xLabelService.commonCancel;
    }
    get okText(){
        return xLabelService.commonOk;
    }
    get colSpan(){
        return this.columns.length + 4 + (this.rowNumberColumn && Object.keys(this.rowNumberColumn).length > 0 ? 1 : 0);
    }
    handleSelectAll(evt){
        const selectList = this.template.querySelectorAll('c-x-data-table-row');
        this.selectAllProperty.set((this.startRowIndex/this.visibleRows), evt.detail.checked);
        this.selectAll = evt.detail.checked;
        for(const row of selectList){
            row.select(evt.detail.checked);
        }
        let endIndex = (this.startRowIndex + this.visibleRows) >= this._data.length ? this._data.length : this.startRowIndex + this.visibleRows;
        
        for(const row of this._data.slice(this.startRowIndex, endIndex)){
            row._selected = evt.detail.checked;
        }
        this.visibledata = this.getVisibleData();
    }

    handleSwingAll(evt){
        for(const row of this._data){
            row._drawer = evt.detail.swingAll;
        }
        this.visibledata = this.getVisibleData();
    }

    handleMutation(evt){
        evt.preventDefault();
        this.doMutation(evt.detail.apiName,evt.detail.rowKey,evt);
    }
    doMutation(apiName,rowKey,evt){
        this.setmColumns();
        let oldRow = {};
        //TODO: Use a Map so we do not have to iterate through the data...
        for(const row of this._data){
            if(row.rowKey === rowKey){
                oldRow = Object.assign({},row);
                if((row[apiName] || evt.detail.value !== '') && row[apiName] !== evt.detail.value && this.notInKeys(apiName)){
                    this.undoHistory.push(this.prepareHistory(apiName,evt.detail.isPicklistChange,row));
                    this.disableEnableActionButton('save',false);
                    row['_updated'] = true;
                }

                if((row[apiName] || evt.detail.value !== '') && row[apiName] !== evt.detail.value){
                    row[apiName] = evt.detail.value;
                }
                if(this.mColumns.has(apiName)
                        && this.mColumns.get(apiName).type === 'reference'){
                    row[this.mColumns.get(apiName).typeAttributes.label.lookupApi] = evt.detail.value ? {
                        [this.mColumns.get(apiName).typeAttributes.isNameField]: evt.detail.label,
                        Id: evt.detail.value
                    } : null;
                }
                if(evt.detail.isPicklistChange){
                    for (let column of this.mColumns.values()){
                        if(column.dependentOn === apiName){
                            row[column.apiName] = ''; 
                        }
                    }
                }
                apiName !== '_drawer' && apiName !== '_selected' &&  this.fireRowChangeEvent(oldRow,row);
                break; 
            }
        };

    }
    fireRowChangeEvent(oldRow,updatedRow){
        if(this.hasRowChangeTemplate || this.rowChangeTemplate){
            this.dispatchEvent(new CustomEvent('rowchange', { detail: {oldRow : oldRow,updatedRow : updatedRow} }));
        }
    }
    setmColumns(){
        if(this.columns && !this.mColumns){
            this.mColumns = this.columns.reduce( (map, column) => {
                map.set(column.apiName, column);
                return map;
            }, new Map());

            if(this.drawer){
                this.mColumns = this.drawer.reduce( (map, column) => {
                    map.set(column.apiName, column);
                    return map;
                }, this.mColumns);
            }
        }
    }
    notInKeys(apiName){
        return apiName != '_drawer' && apiName != '_selected' && apiName != '_updated' && apiName != '_hasSubgrid' && apiName != 'childRowKeys';
    }
    prepareHistory(apiName, isPicklistChange, row){
        if(!row){return;}
        let tempObj = {rowKey:row.rowKey,colId:apiName,value:row[apiName]};
        this.setmColumns();
        if(this.mColumns && this.mColumns.get(apiName)?.type === 'reference'){
            tempObj['lookupApi'] = row[this.mColumns.get(apiName).typeAttributes.label.lookupApi];
        }
        tempObj['isPicklistChange'] = isPicklistChange; 
        return tempObj;
    }
    handleCurrencyCellChange(evt){
        this.doMutation(evt.detail.colId,evt.detail.rowId,evt);
    }
    handleActionClick(evt){
        const actionName = evt.detail.actionName;
        const isGlobal = evt.detail.actionGlobal;
        let actionData = [];
        if(isGlobal){
            actionData = this._data;
        }else{
            for(const row of this._data){
                if(row._selected){
                    actionData.push(row);
                }
            }
        }
        switch (actionName){
            case 'delete':
                this.handleDeleteAction();
                return;
            case 'add':
                this.handleAddRowAction();
                return;
            case 'csvupload':
                this.handleCSVUpload();
                return;
            case 'undo':
                this.handleUndoClick();
                return;
            case 'redo':
                this.handleRedoClick();
                return;
            case 'refresh':
                this.handleRefreshEvent(actionName);
                return;
            case 'csv':
                this.handleExportCSV(actionName);
                return;
            default:

        }
        this.setmColumns();
        actionData = [];
        this.dataHasErrors = false;
        this._data.forEach(item =>{
            let message = xLabelService.requireFieldsMissing + '. [';
            if(item._updated){
                this.mColumns.forEach(innerItem => {
                    if(innerItem.isRequired && (item[innerItem.apiName] === undefined || item[innerItem.apiName] === null || item[innerItem.apiName] === '')){
                        item.hasError = true;
                        message = message + '"' + innerItem.label + '",'; 
                        this.dataHasErrors = true;
                    }
                })
                item.message = (message.endsWith('[') ? null : message.endsWith(',') ? message.substring(0,message.length - 1) + ']' : message);
                if(item.message === null){
                    item.hasError = false;
                    if(this.hasSubGridDetails){
                        item[this.subqueryRelationshipName] = this.checkRowLevelErrorsOnChilds(item[this.subqueryRelationshipName]);
                        if(this.childHasError(item[this.subqueryRelationshipName])){
                            item['_drawer'] = true;
                        }else{
                            actionData.push(item);
                        }
                    }else{
                        actionData.push(item);
                    }
                } 
            }
        });
        if(this.dataHasErrors === true && actionData.length === 0 && this.dataToDelete.length === 0 && this.subgridDataToDelete.length === 0){
            this.visibledata = this.getVisibleData();
            return;
        }
        //actionData = this._data;
        //prune props internal to the table data
        if(actionName === 'csv'){actionData = this._data;}
        let evtData = actionData.map(({_row,_selected, _drawer,_updated,_hasSubgrid,hasError,message,inEditMode,childHasError, ...rest}) => {
            return rest;
        });
        this.hasSubGridDetails && evtData.forEach(row => {
            let updatedRecords = this.filterOnlyUpdatedSubRow(row[this.subqueryRelationshipName]);
            row[this.subqueryRelationshipName] = updatedRecords.length > 0 ? updatedRecords : null;
            let tempRow= this.calculateChildRowKeys(row);
            row['childRowKeys'] = tempRow['childRowKeys'];
        });

        if(evtData.length === 0 && this.dataToDelete.length === 0 && actionName !== 'refresh' && this.subgridDataToDelete.length === 0){
            showToastMessage(this,xLabelService.commonToastInfoTitle,xLabelService.noRecentUpdates,'info');
            return;
        }
        let evtDataToDelete = this.dataToDelete.filter(function(value){return value.Id ? (value.Id != null || value.Id != '') : false })
                                .map(({_row,rowKey,_selected, _drawer,_updated,_hasSubgrid,childRowKeys,hasError,message,inEditMode,childHasError, ...rest}) => {
            return rest;
        });
        let evtSubGridDataToDelete = [];
        if(this.hasSubGridDetails && this.subgridDataToDelete.length !== 0){
            evtSubGridDataToDelete = this.subgridDataToDelete.filter(function(value){return value.Id ? (value.Id != null || value.Id != '') : false })
                                    .map(({_row,rowKey,_selected, _drawer,_updated,_hasSubgrid,childRowKeys,hasError,message,inEditMode,childHasError, ...rest}) => {
                return rest;
            });
            evtSubGridDataToDelete = this.removeAlreadySelectedRows(evtSubGridDataToDelete,evtDataToDelete);
        }
        if(this.hasSubGridDetails &&  evtDataToDelete.length != 0){
            evtDataToDelete = this.deleteUnsavedChildsFromParent(evtDataToDelete);
        }
        this.fireActionEvent(actionName,evtData,evtDataToDelete,evtSubGridDataToDelete);
    }
    deleteUnsavedChildsFromParent(evtDataToDelete){
        evtDataToDelete.forEach(item => {
            item = this.getFilterdSubQueryResults(item);
        })
        return evtDataToDelete;
    }
    getFilterdSubQueryResults(item){
        let childs = [];
        let hasChilds = false;
        item[this.subqueryRelationshipName].forEach(record => {
            if(record.Id && record.Id != null){
                childs.push(record);
                hasChilds = true;
            }
        });
        if(!hasChilds){
            delete item[this.subqueryRelationshipName]; 
        }else{
            item[this.subqueryRelationshipName] = childs;
        }
        return item;
    }
    filterOnlyUpdatedSubRow(childRows){
        let tempChildRows = [];
        childRows.forEach(item => {
            if(item._updated){
                tempChildRows.push(item);
            }
        });
        return tempChildRows;
    }
    checkRowLevelErrorsOnChilds(parentItem){
        parentItem.forEach(item =>{
            let message = xLabelService.requireFieldsMissing + '. [';
            if(item._updated){
                this.subGridMColumns.forEach(innerItem => {
                    if(innerItem.isRequired && (item[innerItem.apiName] === undefined || item[innerItem.apiName] === null || item[innerItem.apiName] === '')){
                        item.hasError = true;
                        message = message + '"' + innerItem.label + '",'; 
                        this.dataHasErrors = true;
                    }
                })
                item.message = (message.endsWith('[') ? null : message.endsWith(',') ? message.substring(0,message.length - 1) + ']' : message);
                if(item.message === null){
                    item.hasError = false;
                } 
            }
        });
        return parentItem;
    }
    removeAlreadySelectedRows(evtSubGridDataToDelete,evtDataToDelete){
        let tempMap = new Map();
        evtDataToDelete.forEach(row =>{
            row[this.subqueryRelationshipName].forEach(subRow => {
                tempMap.set(subRow.rowKey, subRow);
            })
        });
        let subGridDataToDelete = [];
        evtSubGridDataToDelete.forEach(row => {
            if(!tempMap.get(row.rowKey)){
                subGridDataToDelete.push(row);
            }
        })
        return subGridDataToDelete;

    }
    handleExportCSV(actionName){
        if(this.undoHistory.length === 0 && this._data.length >= this.totalRecordsCount){
            this.fireActionEvent(actionName,this._data,[],[]);
        }else{
            let data = {modalFor : 'exportwarning'};
            const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
            csvModal.showWarning(data);
        }
    }
    handleRefreshEvent(actionName){
        if(this.undoHistory.length === 0){
            this.fireActionEvent(actionName,[],[],[]);
        }else{
            let data = {modalFor : 'warning'};
            this.showWarningModal(data);
        }
    }
    handleRefreshSuccess(evt){
        this.fireActionEvent('refresh',[],[],[]); 
        this.closeWarningModal();
    }
    closeWarningModal(){
        const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
        csvModal.closeModal();
    }
    fireActionEvent(actionName,evtData,evtDataToDelete,evtSubGridDataToDelete){
        const xAction = new CustomEvent('xaction', {
            detail: {
                actionName: actionName,
                data: evtData,
                dataToDelete : evtDataToDelete,
                subgridDataToDelete : evtSubGridDataToDelete,
                startRowIndex : this.startRowIndex,
                visibleRows : this.visibleRows,
                dataHasErrors : this.dataHasErrors
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(xAction);
    }
    handleUndoClick(){
        if(this.undoHistory.length === 0){
            showToastMessage(this,xLabelService.commonToastInfoTitle,xLabelService.noRecentUpdates,'info');
            return;
        }
        let lastVal = this.undoHistory[this.undoHistory.length - 1];
        let isArr = Array.isArray(lastVal);
        let index = this._data.map(function(item) { return item.rowKey; }).indexOf(isArr ? lastVal[0].rowKey : lastVal.rowKey);
        let previousRow = index !== -1 ? JSON.parse(JSON.stringify(this._data[index])) : {}; 

        if(lastVal['isChild']){
            this.redoHistory.push({isChild : true, index : lastVal.index, previousData : this._data[lastVal.index], rowKey : lastVal.rowKey, isDeleteCall : lastVal['isDeleteCall'], deletedRows : lastVal['deletedRows']});
            this._data[lastVal.index] = lastVal.previousData;
            if(lastVal.isDeleteCall){
                this.handleSubGridDeletedRows(lastVal.deletedRows, true);
            }
        }else if(isArr){
            if(lastVal[0].hasOwnProperty('index')){
                this.redoHistory.push(lastVal[0].added ? this.addDeletedRowsAgain(lastVal) : this.removeRowsAgain(lastVal));
            }else{
                this.redoHistory.push(this.isArrHistory(lastVal,index));
            }
        }else{
            if(lastVal.colId === this.rowNumberColumn.apiName){
                this.redoHistory.push({rowKey:lastVal.rowKey,colId:lastVal.colId,value: this._data[index][lastVal.colId]});
                this.handleOrderChange({detail : {apiName : lastVal.colId, rowKey : lastVal.rowKey, value : lastVal.value, fromUndo : true}});
            }else{
                this.redoHistory.push(this.prepareHistory(lastVal.colId,lastVal.isPicklistChange,this._data[index]));
                this.doDataMutation(index,lastVal);
            }
        }
        index !== -1 && this.fireRowChangeEvent(previousRow, this._data[index]);
        this.paginatorHelper();
        this.visibledata = this.getVisibleData();
        this.undoHistory.pop();
        this.manageSaveButton();
    }
    handleSubGridDeletedRows(deletedRows, fromUndo){
        if(fromUndo){
            this.subgridDataToDelete = this.subgridDataToDelete.filter(function(value,index){
                return deletedRows.has(value.rowKey) === false;
            });
        }else{
            this.subgridDataToDelete = [...this.subgridDataToDelete, ...deletedRows.values()]
        }
    }
    addDeletedRowsAgain(lastVal){
        let tempArr = [];
        for (let i = 0; i < lastVal.length; i++) {
            let lastValData = lastVal[i].data;
            lastValData['_selected'] = false;
            this._data.splice(lastVal[i].index, 0, lastValData);
            tempArr.push({index : lastVal[i].index, data : lastVal[i].data, added : !lastVal[i].added});

            let dataIndex = this.dataToDelete.map(function(item) { return item.rowKey; }).indexOf(lastValData.rowKey);
            if(dataIndex !== -1){
                this.dataToDelete.splice(dataIndex, 1);
            }
        }
        return tempArr;
    }
    removeRowsAgain(lastVal){
        let tempArr = [];
        for (let i = lastVal.length - 1; i >= 0; i--) {
            this._data.splice(lastVal[i].index, 1);
            tempArr.push({index : lastVal[i].index, data : lastVal[i].data, added : !lastVal[i].added});
            let dataIndex = this.dataToDelete.map(function(item) { return item.rowKey; }).indexOf(lastVal[i].data.rowKey);
            if(dataIndex === -1){
                this.dataToDelete.push(lastVal[i].data);
            }
        }
        tempArr.sort(function(a, b){return a.index - b.index});
        return tempArr;
    }
    manageSaveButton(){
        if(this.undoHistory.length === 0){
            this.disableEnableActionButton('save',true);
        }
    }
    isArrHistory(lastVal,index){
        let tempArr = [];
        for (let i = lastVal.length - 1; i >= 0; i--) {
            tempArr.push(this.prepareHistory(lastVal[i].colId,lastVal.isPicklistChange,this._data[index]));
            this.doDataMutation(index,lastVal[i]);
        }
        return tempArr;
    }
    handleRedoClick(){
        if(this.redoHistory.length === 0){
            showToastMessage(this,xLabelService.commonToastInfoTitle,xLabelService.noRecentUpdates,'info');
            return;
        }
        let lastVal = this.redoHistory[this.redoHistory.length - 1];
        let isArr = Array.isArray(lastVal);
        let index = this._data.map(function(item) { return item.rowKey; }).indexOf(isArr ? lastVal[0].rowKey : lastVal.rowKey);
        let previousRow = index !== -1 ? JSON.parse(JSON.stringify(this._data[index])) : {}; 

        if(lastVal['isChild']){
            this.undoHistory.push({isChild : true, index : lastVal.index, previousData : Object.assign({},this._data[lastVal.index]), isDeleteCall : lastVal['isDeleteCall'], deletedRows : lastVal['deletedRows']});
            this._data[lastVal.index] = lastVal.previousData;
            if(lastVal.isDeleteCall){
                this.handleSubGridDeletedRows(lastVal.deletedRows, false);
            }
        }else if(isArr){
            if(lastVal[0].hasOwnProperty('index')){
                this.undoHistory.push(lastVal[0].added ? this.addDeletedRowsAgain(lastVal) : this.removeRowsAgain(lastVal));
            }else{
                this.undoHistory.push(this.isArrHistory(lastVal,index));
            }
        }else{
            if(lastVal.colId === this.rowNumberColumn.apiName){
                this.undoHistory.push({rowKey:lastVal.rowKey,colId:lastVal.colId,value: this._data[index][lastVal.colId]});
                this.handleOrderChange({detail : {apiName : lastVal.colId, rowKey : lastVal.rowKey, value : lastVal.value,fromRedo:true}});
            }else{
                this.undoHistory.push(this.prepareHistory(lastVal.colId,lastVal.isPicklistChange,this._data[index]));
                this.doDataMutation(index,lastVal);
            }
        }
        index !== -1 && this.fireRowChangeEvent(previousRow, this._data[index]);
        this.disableEnableActionButton('save',false);
        this.paginatorHelper();
        this.visibledata = this.getVisibleData();
        this.redoHistory.pop();
    }
    doDataMutation(index, lastVal){
        this._data[index][lastVal.colId] = lastVal.value;
        if(lastVal.isPicklistChange){
            for (let column of this.mColumns.values()){
                if(column.dependentOn === lastVal.colId){
                    this._data[index][column.apiName] = '';
                }
            }
        }
        if(lastVal.lookupApi){
            this._data[index][this.mColumns.get(lastVal.colId).typeAttributes.label.lookupApi] = lastVal.lookupApi;
        }
    }
    handleDeleteAction(){
        let tempDelData = [];
        let tempUndoData = [];
        this._data = this._data.filter(function(value,index){ 
            if(value._selected){
                tempDelData.push(value);
                tempUndoData.push({index : index, data : value,added : true});
            }
            return value._selected === false;
        });
        if(tempDelData.length === 0){
            showToastMessage(this,xLabelService.commonToastInfoTitle,xLabelService.pleaseSelectARecord,'info');
        }else{
            this.undoHistory.push(tempUndoData);
            this.disableEnableActionButton('save',false);
            this.dataToDelete = [...this.dataToDelete,...tempDelData];
            this.paginatorHelper();
            this.visibledata = this.getVisibleData();
            this.selectAll = false;
            this.selectAllProperty.forEach((value, key) => {
                this.selectAllProperty.set(key,false);
            });
        }
    }
    handleAddRowAction() {
        if(this.undoHistory.length !== 0 && this.hasMoreRecordsToLoad){
            this.showWarningModal({modalFor : 'warning',modalFrom : 'addrow',offset : this.startRowIndex});
        }else{
            this.fireAddrowEvent();
        }
    }
    
    //column sorting
    handleColumnSorting(evt){
        this.currentSortingInfo = JSON.parse(JSON.stringify(evt.detail));
        if(this.undoHistory.length !== 0){
            let data = {modalFor : 'warning',modalFrom : 'sort',offset : this.startRowIndex, fieldApiName : evt.detail.apiName};
            this.showWarningModal(data);
        }else{
            this.sortTable();
            this.visibledata = this.getVisibleData();
        }
    }
    showWarningModal(data){
        const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
        csvModal.showWarning(data);
    }
    sortTable(){
        let self = this;
        this._data.sort(function(a, b){
            let first = a[self.currentSortingInfo.apiName] ? self.currentSortingInfo.fieldType === 'reference' ? 
                a[self.currentSortingInfo.refrenceField].Name : a[self.currentSortingInfo.apiName] : '',
                second = b[self.currentSortingInfo.apiName] ? self.currentSortingInfo.fieldType === 'reference' ? 
                b[self.currentSortingInfo.refrenceField].Name : b[self.currentSortingInfo.apiName] : '';
                
            if(self.currentSortingInfo.sortOrder === 'ASC'){
                return self.sortHelper(self.currentSortingInfo.fieldType,first,second);
            }else{
                return self.sortHelper(self.currentSortingInfo.fieldType,second,first);
            }
        });
    }
    sortHelper(fType, first,second){
        switch(fType){
            case "date":
            case "datetime":
                return new Date(first) - new Date(second);
            case "number":
            case "percent":
            case "currency":
                return (first === '' ? 0 : first) - (second === '' ? 0 : second);
            case "checkbox":
                return (first === second)? 0 : first? -1 : 1; 
            default : 
                return first.localeCompare(second);
        }

    }
    //csv upload and modal properties 
    handleCloseModal(evt){
        if(evt.detail.modalData && evt.detail.modalData.modalFrom === 'pageChange'){
            let paginator = this.template.querySelector('c-paginator');
            paginator.moveToPage(Math.floor(this.startRowIndex/10) + 1);
        }else if(evt.detail.modalData && evt.detail.modalData.modalFrom === 'sort'){
            let headerComp = this.template.querySelector('[data-id="datatable-header"]');
            headerComp && headerComp.updateSortOrder(evt.detail.modalData.fieldApiName);
        }else if(evt.detail.modalData && evt.detail.modalData.modalFrom === 'addrow'){
            this.pendingAction = '';
        }
        this.closeWarningModal();
    }
    
    //row Actions
    handleRowAction(evt){
        switch(evt.detail.actionName){
            case 'copy':
                this.handleCopyRecord(evt.detail.row.rowKey);
                break;
            case 'edit':
                this.handleEditRecord(evt.detail.row.rowKey,evt);
                break;
            case 'delete':
                this.handleDeleteRecord(evt.detail.row.rowKey);
                break;
            default:
                console.error('No action Defined');
        }
    }
    handleCopyRecord(rowKey){
        this.setmColumns();
        if(this.relationshipName === ''){
            let relation = this.objectInfo.data.childRelationships.filter(item =>{
                return item.childObjectApiName === this.childReference.split('.')[0];
            });
            this.relationshipName = relation[0].fieldName ? relation[0].fieldName : '';
        }
        let index = this._data.map(function(item) { return item.rowKey; }).indexOf(rowKey);
        let recordToCopy = Object.assign({}, this._data[index]);
        [...this.columns,...this.drawer].forEach(item => {
            if(item.isAutoNumber){
                recordToCopy[item.apiName] = '';
            }
        })
        recordToCopy['rowKey'] = this.gen.next().value;
        recordToCopy['_updated'] = true;
        delete recordToCopy['Id'];
        recordToCopy[this.relationshipName] = this.recordId;
        recordToCopy[this.subqueryRelationshipName] = this.copyChildRecords(recordToCopy);
        recordToCopy = this.calculateChildRowKeys(recordToCopy);
        recordToCopy['_row'] = Object.assign({}, []);
        this.undoHistory.push([{index: index + 1, data : recordToCopy}]);
        this.disableEnableActionButton('save',false);
        this._data.splice(index + 1,0,recordToCopy);
        if((index+2) > (this.startRowIndex + this.visibleRows)){
            this.afterSave((this.startRowIndex/this.visibleRows)+2);
        }
        this.visibledata = this.getVisibleData();
    }
    copyChildRecords(recordToCopy){
        if(this.hasSubGridDetails){
            let subRecords = [];
            recordToCopy[this.subqueryRelationshipName].forEach(subRow => {
                let subRecordToCopy = Object.assign({}, subRow);
                this.subGridColumns.forEach(item => {
                    if(item.isAutoNumber || item.isNameField){
                        subRecordToCopy[item.apiName] = '';
                    }
                })
                subRecordToCopy['rowKey'] = this.gen.next().value;
                subRecordToCopy['_updated'] = true;
                delete subRecordToCopy['Id'];
                delete subRecordToCopy[this.subgridParentApiName];
                subRecordToCopy['_row'] = Object.assign({}, []);
                subRecords.push(subRecordToCopy);
            });
            return subRecords; 
        }
        return null;
    }
    handleDeleteRecord(rowKey){
        let tempDelData = [];
        let self = this;
        this._data = this._data.filter(function(value,index){ 
            if(value.rowKey === rowKey){
                tempDelData.push(value);
                self.undoHistory.push([{index : index, data :value,added:true}]);
            }
            return value.rowKey !== rowKey;
        });
        this.disableEnableActionButton('save',false);
        this.visibledata = this.getVisibleData();
        this.paginatorHelper();
        this.dataToDelete = [...this.dataToDelete,...tempDelData];
    }
    paginatorHelper(){
        let totalPages = Math.max(Math.ceil(this._data.length/this.visibleRows), 1) - 1;
        if((totalPages*this.visibleRows) < this.startRowIndex){
            this.afterSave((this.startRowIndex/this.visibleRows));
        }
    }
    handleEditRecord(rowKey,evt){
        let modalData = {actionText :xLabelService.commonSave,cancelText :xLabelService.commonCancel,
            modalFor : 'editRecord',rowKey : rowKey, objectName : this.childReference.split('.')[0],
            allColumns:[...this.requiredColumns,...this.columns,...this.drawer],row:evt.detail.row,undoHistory:this.undoHistory};
        const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
        csvModal.showModal(modalData);
    }

    handleModalAction(evt){
        if(evt.detail.actionFor === 'editRecord'){
            let index = this._data.map(function(item) { return item.rowKey; }).indexOf(evt.detail.row.rowKey);
            this.fireRowChangeEvent(this._data[index],evt.detail.row);
            this._data[index] = evt.detail.row;
            this.disableEnableActionButton('save',false);
            this.visibledata = this.getVisibleData();
            this.undoHistory = evt.detail.undoHistory;
            const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
            csvModal.closeModal();
        }else if(evt.detail.actionFor === 'uploadFile'){
            let modalData = {actionText :xLabelService.commonNext,cancelText :xLabelService.commonCancel,
                modalFor : 'mapFields',allColumns:[...this.columns,...this.drawer],fields : evt.detail.fields,
                fieldsMap : this.fieldsMap};
            const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
            csvModal.closeModal();
            csvModal.showModal(modalData);
        }else if(evt.detail.actionFor === 'mapFields'){
            const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
            csvModal.closeModal();
            this.handleCSVResult(evt.detail.data,evt.detail.fieldsMap[evt.detail.userMapping])
        }
    }
    handleCSVResult(result,selectedMappings){
        let mappings  = selectedMappings.reduce( (map, column) => {
                map.set(column.key, column.value);
                return map;
            }, new Map());
        result.forEach(record => {
            let index = this._data.map(function(item) { return item.Id; }).indexOf(record.Id || 0);
            let keys = Object.keys(record);
            if(index === -1){
                let newRow = this.newRowHelper();
                keys.forEach(item => {
                    if(mappings.has(item) && item !== this.relationshipName)
                        newRow[mappings.get(item)] = record[item];
                });
                newRow['_row'] = Object.assign({}, newRow);
                this._data.unshift(newRow);
            }else{
                keys.forEach(item => {
                    if((this._data[index][mappings.get(item)] || record[item] != '') && this._data[index][mappings.get(item)] != record[item]){
                        this._data[index][mappings.get(item)] = record[item];
                        this._data[index]['_updated'] = true; 
                     }
                });
            }
        });
        this.fireDataSaveEvent();
        //this.visibledata = this.getVisibleData();
    }
    newRowHelper(){
        let key = this.gen.next().value;
        if(this.relationshipName === ''){
            let relation = this.objectInfo.data.childRelationships.filter(item =>{
                return item.childObjectApiName === this.childReference.split('.')[0];
            });
            this.relationshipName = relation[0].fieldName ? relation[0].fieldName : '';
        }
        if(!this.mColumns){
            this.setmColumns();
        }
        let newRow = {_selected:false,_drawer:false,rowKey:key,_updated:true,inEditMode:true};
        newRow['attributes'] = {'type': this.childReference.split('.')[0]};
        newRow[this.relationshipName] = this.recordId;
        if(this.mColumns.get(this.relationshipName)){
            newRow[this.mColumns.get(this.relationshipName).typeAttributes.label.lookupApi] = {Name: this.recordInfo ? this.recordInfo.data.fields[this.nameField.split('.')[1]].value : '',Id:this.recordId};
        }
        newRow['_row'] = Object.assign({}, newRow);
        newRow['_hasSubgrid'] = this.hasSubGridDetails;
        newRow['childRowKeys'] = '';
        return newRow;
    }
    fireDataSaveEvent(){
        const evtData = this._data.filter(function(value){return value._updated === true; })
                    .map(({_row,_selected, _drawer,_updated,_hasSubgrid,hasError,message,inEditMode,childRowKeys,childHasError, ...rest}) => {
                            return rest;
        });
        const evtDataToDelete = this.dataToDelete.filter(function(value){return value.Id ? (value.Id != null || value.Id != '') : false })
                                .map(({_row,rowKey,_selected, _drawer,_updated,_hasSubgrid,childRowKeys,hasError,message,inEditMode,childHasError, ...rest}) => {
            return rest;
        });
        const xAction = new CustomEvent('xaction', {
            detail: {
                actionName: 'save',
                data: evtData,
                dataToDelete : evtDataToDelete
                },
                bubbles: true,
                composed: true
            });
        this.dispatchEvent(xAction);
    }
    
    @api
    afterSave(pageNum) {
        let paginator = this.template.querySelector('c-paginator');
        if (paginator) {
            paginator.moveToPage(pageNum);
        }
        this.visibledata = this._data.slice(0, this.visibleRows);
    }
    disableEnableActionButton(name,disable){
        this.actions.forEach(item => {
            if(item.name === name){
                item.disabled = disable;
            }
        })
    }
    handleCreateTemplate(){
        let modalData = {actionText :xLabelService.commonNext,cancelText :xLabelService.commonCancel,
            modalFor : 'createTemplate',childName : this.childReference.split('.')[0], parentName :this.childReference.split('.')[1],
            csvFileName : this.file.name};
        const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
        csvModal.closeModal();
        csvModal.showCreateTemplate(modalData);
    }
    handleCancelCreation(){
        let modalData = {actionText :xLabelService.importCsv,cancelText :xLabelService.commonCancel,
            modalFor : 'templates',importTemplates : this.existingImportTemplate,file : this.file};
        const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
        csvModal.closeModal();
        csvModal.showModaForTemplate(modalData);
    }
    handleCSVUpload(){
        let modalData = {actionText :xLabelService.commonNext,cancelText :xLabelService.commonCancel,
            modalFor : 'uploadFileModal',hasGridReference : true, modalHeader : xLabelService.csvUploadYourFile};
        const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
        csvModal.showModalUploadFile(modalData);
    }
    handleImportModalAction(evt){
        this.file = evt.detail.file;
        getImportTemplates({detailObject : this.childReference.split('.')[0], parentObject :this.childReference.split('.')[1]})
            .then((result)=>{
                this.existingImportTemplate = result;
                let modalData = {actionText :xLabelService.importCsv,cancelText :xLabelService.commonCancel,
                    modalFor : 'templates',importTemplates : result,file : this.file};
                const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
                csvModal.closeModal();
                csvModal.showModaForTemplate(modalData);
            })
            .catch((error)=>{
                console.error(error);
            })
    }
    handleSaveRecord(evt){
        let existingTemp = this.existingImportTemplate.map((item) => ({
            ...item,
            selected: false       
        }));
        existingTemp.push({id: evt.detail.recordId, name : evt.detail.name,hasHeaders : evt.detail.hasHeaders});
        this.existingImportTemplate = existingTemp;
        let modalData = {actionText :xLabelService.commonImport,cancelText :xLabelService.commonCancel,modalHeader : xLabelService.importFields,
            modalFor : 'mapping',file : this.file, recordId : evt.detail.recordId, hasHeaders : evt.detail.hasHeaders,
            previewLabel : xLabelService.preview, childObj : this.childReference.split('.')[0], picklistValue : evt.detail.recordId};
        const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
        csvModal.closeModal();
        csvModal.showMappingTable(modalData);
    }
    handleMappingSave(evt){
        this.mappingObj = {_data : evt.detail._data, data : evt.detail.data,fieldDefinitions : evt.detail.fieldDefinitions};
        let modalData = {actionText :xLabelService.importCsv,cancelText :xLabelService.commonCancel,file : this.file,
            modalFor : 'templates',importTemplates : this.existingImportTemplate,mappingObj : this.mappingObj, picklistValue : evt.detail.picklistValue};
        const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
        csvModal.closeModal();
        csvModal.showModaForTemplate(modalData);
    }
    handleRecordSave(){
        showToastMessage(this, xLabelService.commonSuccess, xLabelService.dataSavedSuccessfully, 'success');
        const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
        csvModal.closeModal();
        const xAction = new CustomEvent('xaction', {
            detail: {
                actionName: 'refresh',
                },
                bubbles: true,
                composed: true
            });
        this.dispatchEvent(xAction);
    }
    handleOrderChange(evt){
        let value = evt.detail.value ? parseInt(evt.detail.value) :  this._data.length;
        let index = this._data.map(function(item) { return item.rowKey; }).indexOf(evt.detail.rowKey || 0);
        let recordToMove = this._data[index];
        if(!evt.detail.fromUndo && !evt.detail.fromRedo){
            this.undoHistory.push({rowKey:evt.detail.rowKey,colId:this.rowNumberColumn.apiName,value: recordToMove[this.rowNumberColumn.apiName]});
        }
        recordToMove[this.rowNumberColumn.apiName] = value;
        let movingToIndex = (value < 0) ? 1 : (value > this._data.length) ? this._data.length : value;
        this._data.splice(index,1);
        this._data.splice((movingToIndex - 1) , 0, recordToMove);
        this._data[(movingToIndex - 1)]['_updated'] = true;

        let start = index < movingToIndex ? index : movingToIndex - 1;

        if(this._data.length - start > 1){
            for(let i = start; i< this._data.length; i++){
                if( this._data[i][this.rowNumberColumn.apiName] !== (i+1)){
                    if(this._data[i][this.rowNumberColumn.apiName] !== i+1){
                        this._data[i][this.rowNumberColumn.apiName] = i + 1;
                        this._data[i]['_updated'] = evt.detail.fromUndo ? false : true;
                    }
                }
            }
        }
        this.disableEnableActionButton('save',false);
        this.visibledata = this.getVisibleData();
    }
    @api
    moveToPage(offset){
        this.handlePageChange({detail : offset}, false);
    }
    handlePageChange({ detail : offset}, canShowModal = true) {
        if(this._data.length > offset){
            this.startRowIndex = offset;
            this.visibledata = this._data.slice(offset, offset + this.visibleRows);
            this.selectAll = this.selectAllProperty.get((this.startRowIndex/this.visibleRows));
        }else if(this.undoHistory.length !== 0 && canShowModal){
            this.pendingAction = 'pageChange';
            this.moveToPageWhenLoadCompletes = offset;
            let data = {modalFor : 'warning',modalFrom : 'pageChange',offset : offset};
            this.showWarningModal(data);
        }else if(canShowModal){
            this.pendingAction = 'pageChange';
            this.moveToPageWhenLoadCompletes = offset;
        }
    }
    handleSavingError(evt){
        let modalData = {cancelText :xLabelService.commonCancel,modalFor : 'errortable',columns : evt.detail.columns, rowData : evt.detail.rowData,message : evt.detail.message};
        const csvModal = this.template.querySelector(`c-x-modal-popup[data-id="datatable-modal"]`);
        csvModal.closeModal();
        csvModal.showErrorTable(modalData);
    }

    @api
    handleAddRowActionResponse(rows,isLoad) {
        if (isLoad) {
            this.handleLoadRows(rows);
            return;
        }
        let lastLineOrder = 0;
        if(this.rowNumberColumn && Object.keys(this.rowNumberColumn).length !== 0){
            let tempObj = JSON.parse(JSON.stringify(this._data));
            let fName = this.rowNumberColumn.apiName;
            tempObj.sort(function(a, b){
                return a[fName] - b[fName];
            });
            lastLineOrder = tempObj.length > 0 ? tempObj[tempObj.length - 1][fName] : 0;
        } 
        let tempHistory = [];
        rows.forEach(item => {
            let newRow = this.getRowWithExtraKeys(item);
            if (this.rowNumberColumn && Object.keys(this.rowNumberColumn).length !== 0) {
                newRow[this.rowNumberColumn.apiName] = ++lastLineOrder;
            }
            newRow = this.setSubQueryRecordDetails(newRow);
            if(this.hasSubGridDetails){
                newRow[this.subqueryRelationshipName] = newRow[this.subqueryRelationshipName].map(subrow => 
                    subrow = this.getSubrowWithDefaultData(subrow,newRow)
                );
            }
            tempHistory.push({ index: this._data.length, data: newRow, added: false })
            this._data.push(newRow);
        });
        tempHistory.sort(function(a,b){return a.index - b.index;});
        this.undoHistory.push(tempHistory);
        this.calculateAllParentsChildRowKeys();
        this.disableEnableActionButton('save',false);
        this.visibledata = this.getVisibleData(true);
        let paginator = this.template.querySelector('c-paginator');
        if (paginator) {
            this.startRowIndex = (Math.max(Math.ceil(this._data.length/this.visibleRows), 1) - 1) * 10;
            paginator.moveToPage(Math.max(Math.ceil(this._data.length / this.visibleRows), 1));
        } else {
            this.visibledata = this._data.slice(0, this.visibleRows);
        }
    }
    getRowWithExtraKeys(item) {
        let row = Object.assign({}, item);
        let key = this.gen.next().value;
        if(!this.mColumns){
            this.setmColumns();
        }
        row['_selected'] = false;
        row['_drawer'] = false;
        row['_hasSubgrid'] = this.hasSubGridDetails;
        row['_updated'] = true;
        row['inEditMode'] = true;
        row['rowKey'] = key;
        row['childRowKeys'] = '';
        row['attributes'] = {'type': this.childReference.split('.')[0]};
        row['_row'] = Object.assign({}, row);
        return row;
    }

    @api 
    handleRowChangeResponse(response,rowKey){
        for(let row of this._data){
            if(row.rowKey === rowKey){
                Object.keys(response).forEach(item => {
                    if(item !== this.subqueryRelationshipName){
                        row[item] = response[item];
                    }
                });
                row[this.subqueryRelationshipName] && this.handleSubgridRecordsAfterChanges(response,row);
                row = this.calculateChildRowKeys(row);
            }
        }
    }
    handleSubgridRecordsAfterChanges(response,row){
        for (let i = 0; i < row[this.subqueryRelationshipName].length; i++) {
            Object.keys(response[this.subqueryRelationshipName][i]).forEach(item => {
                    row[this.subqueryRelationshipName][i][item] = response[this.subqueryRelationshipName][i][item];
            });
        }
    }

    handleSubGridAction(evt){
        let index = this._data.map(function(item) { return item.rowKey; }).indexOf(evt.detail.row.rowKey);
        if(index !== -1){
            if(evt.detail.actionName === 'add'){
                this.handleSubgridAddrow(index);
            }else{
                this.handleSubgridDeleteRows(index);
            }   
        }
    }
    handleSubgridAddrow(index){
        let tempData = Object.assign({},this._data[index]);
        let previousData = JSON.parse(JSON.stringify(this._data[index]));
        let tempObj = this.getSubrowWithDefaultData({},tempData);
        tempData[this.subqueryRelationshipName].push(tempObj);
        tempData = this.calculateChildRowKeys(tempData);
        this.undoHistory.push({isChild : true, previousData : previousData, index : index, rowKey : this._data[index]['rowKey']});
        this._data[index] = tempData; 
        this.disableEnableActionButton('save',false);
        this.visibledata = this.getVisibleData();
    }
    handleSubgridDeleteRows(parentIndex){
        let tempDelData = [];
        let tempDeleteMap = new Map();
        let tempData = Object.assign({},this._data[parentIndex]);
        let previousData = JSON.parse(JSON.stringify(this._data[parentIndex]));
        tempData[this.subqueryRelationshipName] = tempData[this.subqueryRelationshipName].filter(function(value,index){ 
            if(value._selected){
                tempDelData.push(value);
                tempDeleteMap.set(value.rowKey, value);
            }
            return value._selected === false;
        });
        if(tempDelData.length === 0){
            showToastMessage(this,xLabelService.commonToastInfoTitle,xLabelService.pleaseSelectARecord,'error');
        }else{
            this.subgridDataToDelete = [...this.subgridDataToDelete,...tempDelData];
            if(tempData[this.subqueryRelationshipName].length === 0){
                let tempArr = this.getSubrowWithDefaultData({},this._data[parentIndex]);
                tempData[this.subqueryRelationshipName].push(tempArr);        
            }
            tempData = this.calculateChildRowKeys(tempData);
            this.undoHistory.push({isChild : true, previousData : previousData, index : parentIndex, isDeleteCall : true, deletedRows : tempDeleteMap, rowKey : this._data[parentIndex]['rowKey']});
            this._data[parentIndex] = tempData; 
        }
        this.disableEnableActionButton('save',false);
        this.visibledata = this.getVisibleData();
    }
    handleSubGridMutation(evt){
        evt.preventDefault();
        this.doSubgridMutation(evt);
    }
    doSubgridMutation(evt){
        this.setmSubGridColumns();
        let index = this._data.map(function(item) { return item.rowKey; }).indexOf(evt.detail.parentRowKey);

        if(index !== -1){
            let tempData = Object.assign({},this._data[index]);
            let previousData = JSON.parse(JSON.stringify(this._data[index]));
            tempData[this.subqueryRelationshipName] = tempData[this.subqueryRelationshipName].map(row => 
                        row = this.subGridMutationHelper(evt,row)
            );
            tempData['_updated'] = true;
            this.disableEnableActionButton('save',false);
            this.notExtraCols(evt) &&  this.fireRowChangeEvent(previousData,tempData);
            this.notExtraCols(evt) &&  this.undoHistory.push({isChild : true, previousData : previousData, newData : tempData, index : index, rowKey : this._data[index]['rowKey']});
            this._data[index] = tempData;
        }
        this.visibledata = this.getVisibleData();
    }
    notExtraCols(evt){
        return evt.detail.evtData.apiName !== '_drawer' && evt.detail.evtData.apiName !== '_selected';
    }
    subGridMutationHelper(evt,row){
        if(row.rowKey === evt.detail.evtData.rowKey){
            if((row[evt.detail.evtData.apiName] || evt.detail.evtData.value !== '') && row[evt.detail.evtData.apiName] !== evt.detail.evtData.value && this.notInKeys(evt.detail.evtData.apiName)){
                row['_updated'] = true;
            }
            if((row[evt.detail.evtData.apiName] || evt.detail.evtData.value !== '') && row[evt.detail.evtData.apiName] !== evt.detail.evtData.value){
                row[evt.detail.evtData.apiName] = evt.detail.evtData.value;
            }
            if(this.subGridMColumns.has(evt.detail.evtData.apiName)
                    && this.subGridMColumns.get(evt.detail.evtData.apiName).type === 'reference'){
                row[this.subGridMColumns.get(evt.detail.evtData.apiName).typeAttributes.label.lookupApi] = evt.detail.evtData.value ? {
                    [this.subGridMColumns.get(evt.detail.evtData.apiName).typeAttributes.isNameField]: evt.detail.evtData.label,
                    Id: evt.detail.evtData.value
                } : null;
            }
            if(evt.detail.evtData.isPicklistChange){
                for (let column of this.subGridMColumns.values()){
                    if(column.dependentOn === evt.detail.evtData.apiName){
                        row[column.apiName] = ''; 
                    }
                }
            }
        }
        return row;
    }
    setmSubGridColumns(){
        if(!this.subGridMColumns){
            this.subGridMColumns = this.subGridColumns.reduce( (map, column) => {
                map.set(column.apiName, column);
                return map;
            }, new Map());
        }
    }
    handleSubGridCurrencyCellChange(evt){
        this.doSubgridMutation(evt);
    }
    handleSubGridSelectAll(evt){
        let index = this._data.map(function(item) { return item.rowKey; }).indexOf(evt.detail.parentRowKey);

        if(index !== -1){
            for(const row of this._data[index][this.subqueryRelationshipName]){
                row._selected = evt.detail.checked;
            }
        }
        this.visibledata = this.getVisibleData();
    }
    calculateAllParentsChildRowKeys(){
        if(this.hasSubGridDetails){
            let tempRows = Object.assign([],this._data);
            tempRows.forEach(row => {
                row = this.calculateChildRowKeys(row);
            });
            this._data = tempRows;
        }
    }
    calculateChildRowKeys(row){
        if(this.hasSubGridDetails){
            let tempRow = Object.assign({},row);
            let childRowKeys = '';
            tempRow[this.subqueryRelationshipName] && tempRow[this.subqueryRelationshipName].forEach(item => {
                childRowKeys = childRowKeys + item.rowKey + ','; 
            });
            tempRow['childRowKeys'] = childRowKeys.endsWith(',') ? childRowKeys.substring(0,childRowKeys.length -1) : childRowKeys;
            return tempRow;
        }
        return row;
    }
    get totalNumberOfRecords(){
        if(!this.hasMoreRecordsToLoad){
            return this._data && this._data.length || 0;
        }else{
            return this.totalRecordsCount;
        }
    }
}