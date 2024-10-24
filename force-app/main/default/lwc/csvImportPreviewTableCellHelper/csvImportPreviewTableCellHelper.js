import { LightningElement,api } from 'lwc';

export default class CsvImportPreviewTableCellHelper extends LightningElement {
    @api column;
    @api fieldDefinitions;
    @api rowData;
    @api record;
    @api options;

    get fieldValue(){
        return this.rowData[this.column.apiName];
    }
    get hasOptions(){
        return this.options.length > 0 ? true : false;
    }
    handlePicklistChange(evt){
        const mutation = new CustomEvent('selectionchange', {
            detail: {
                rowKey : this.rowData.rowKey,
                apiName: this.column.apiName,
                value: evt.target.value
            },bubbles : true,
            composed : true
        });
        this.dispatchEvent(mutation);

    }
    get radioOption(){
        return [{ label: '', value: 'true' }];
    }
    get isRadioButton(){
        return this.column.isRadioButton;
    }
    handleChange(evt){
        const mutation = new CustomEvent('groupbychange', {
            detail: {
                rowKey : this.rowData.rowKey,
                apiName: this.column.apiName,
                value: evt.target.value
            },bubbles : true,
            composed : true
        });
        this.dispatchEvent(mutation);
    }
    get textClass(){
        return this.column.apiName === 'Error' ? 'slds-truncate slds-size_3-of-3 slds-text-color_error' : 'slds-truncate slds-size_3-of-3';
    }
}