import { LightningElement, api, track } from 'lwc';

export default class XDataTableSubgrid extends LightningElement {
    @api subGridActions;
    @api columns;
    @api subGridData;
    @api colSpan;
    @api subqueryRelationshipName;
    @api row;
    @api childReference;
    @api keyField;

    hasDrawer = false;
    @track selectAll = false;
    @track columnsToDisplay = {errorColumn : true, checkboxColumn : true, actionColumn : false,showSortButton : false};
    
    get gridData(){
        return this.subGridData && this.subqueryRelationshipName && JSON.parse(JSON.stringify(this.subGridData[this.subqueryRelationshipName]));
    }
    handleActionClick(evt){
        this.dispatchEvent(new CustomEvent('subgridaction', { 
            detail: {
                row : this.subGridData,
                actionName : evt.detail.actionName
            },
            bubbles : true,
            composed : true
         }));
    }
    handleSelectAll(evt){
        const selectList = this.template.querySelectorAll('c-x-data-table-row');
        for(const row of selectList){
            row.select(evt.detail.checked);
        }
        this.dispatchEvent(new CustomEvent('select', { 
            detail: {
                parentRowKey : this.subGridData.rowKey,
                checked : evt.detail.checked
            }
         }));
    }
    handleMutation(evt){
       this.fireMutation(evt.detail);
    }
    handleCurrencyCellChange(evt){
        let tempDetail = {
                apiName : evt.detail.colId, 
                rowKey : evt.detail.rowId, 
                value : evt.detail.value, 
                isPicklistChange : false
            };
        this.fireMutation(tempDetail);
    }
    fireMutation(resp){
        this.dispatchEvent(new CustomEvent('mutation', { 
            detail: {
                parentRowKey : this.subGridData.rowKey,
                evtData : resp
            }
         }));
    }
}