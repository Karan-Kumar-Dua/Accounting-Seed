import { LightningElement, api } from 'lwc';
import { LabelService } from 'c/utils';

export default class CsvImportPreviewTableCell extends LightningElement {
    @api column;
    @api fieldDefinitions;
    @api rowData;
    @api record;

    get options(){
        let allOptions = [];
        let self=this;
        if(this.fieldDefinitions){
            switch(this.column.type){
                case 'object' :
                    if (allOptions.length === 0) {
                        self.fieldDefinitions.targetObjects.forEach(item => {
                            allOptions.push({ label: item.label, value: item.value });
                        });
                    }
                    return allOptions;
                case 'field':
                    if (!self.rowData.targetObject) { return []; }
                    allOptions = [{ label: LabelService.commonNone, value: '' }];
                    self.rowData.targetObject && self.fieldDefinitions.targetFields[self.rowData.targetObject].map(item =>{
                        allOptions.push({label : item.label, value : item.apiName});
                    });
                    return allOptions;
                case 'lookupType':
                    if(!self.rowData.targetObject){return [];}
                    let index = self.fieldDefinitions.targetFields[self.rowData.targetObject]
                                .map(function(item) { return item.apiName; }).indexOf(self.rowData.targetField);

                    if(index !== -1 && self.fieldDefinitions.targetFields[self.rowData.targetObject][index].type === 'REFERENCE'){
                        self.fieldDefinitions.lookupTypes.forEach(item => {
                            allOptions.push({ label: item.label, value: item.value });
                        });
                        return allOptions;
                    }
                    return [];
                case 'lookupField':
                    if(!self.rowData.targetObject){return [];}
                    if(self.rowData.lookupType === 'Name Field'){
                        return [{label : LabelService.commonName, value : 'name'}];
                    }else if(self.rowData.lookupType === 'External Id'){
                        let index = self.fieldDefinitions.targetFields[self.rowData.targetObject]
                                    .map(function(item) { return item.apiName; }).indexOf(self.rowData.targetField);
                        if (index !== -1) {
                            self.fieldDefinitions.targetFields[self.rowData.targetObject][index].externalIdFields.forEach(item => {
                                allOptions.push({ label: item.label, value: item.value });
                            });
                            return allOptions;
                        }
                        return [];
                    }
                    break;
                default:
                    
            }
        }
        return allOptions;
    }
    getSortedOptions(element){
        element.sort(function(a,b){return a.label.localeCompare(b.label);});
        return element;
    }
}