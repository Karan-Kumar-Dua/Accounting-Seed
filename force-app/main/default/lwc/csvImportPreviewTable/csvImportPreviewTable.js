import { LightningElement,api } from 'lwc';

export default class CsvImportPreviewTable extends LightningElement {
    @api columns;
    @api rowData;
    @api fieldDefinitions;
    @api record;

    get rows(){
        if(this.rowData && this.rowData.length > 0){
            if(this.rowData[0]['header']){return this.rowData;}
            let tempData = JSON.parse(JSON.stringify(this.rowData));
            tempData.forEach((item,index) =>{
                item['header'] = index;
            });
            return tempData;
        }else{
            return false;
        }
    }
}