import createRowCacheEnabled from '@salesforce/apex/ALMRowTemplateHelper.createRowCacheEnabled';
import createRowCacheDisabled from '@salesforce/apex/ALMRowTemplateHelper.createRowCacheDisabled';
import hasRowChangeTemplate from '@salesforce/apex/ALMRowTemplateHelper.hasRowChangeTemplate';
import updateRow from '@salesforce/apex/ALMRowTemplateHelper.updateALMRow';

export default class XRowService{ 
    cachedRow;
    async createRows(stateJson, templateName, enableCaching) {
        let eventState = JSON.parse(stateJson);
        if (enableCaching) {
            if (!this.cachedRow) {
                this.cachedRow = await createRowCacheEnabled({ 'stateJson': stateJson, 'templateName': templateName });
            }
            return this.prepareCachedRow(eventState);
        }
        return await createRowCacheDisabled({'stateJson': stateJson, 'templateName': templateName});
    }
    prepareCachedRow(eventStatus){
        let cachedRecords = [];
        let count = eventStatus.createRowsCount, rowIndex =0;
        while (count > 0){
            if(rowIndex === this.cachedRow.length){
                rowIndex=0;
            }
            cachedRecords.push(this.cachedRow[rowIndex]);
            rowIndex++;
            count--;
        }
        return cachedRecords;
    }
    async hasRowChangeTemplate(objectApiName){
        return await hasRowChangeTemplate({'objectApiName' : objectApiName});
    }
    async updateRow(rowChangeJson,templateName){
        return await updateRow({'rowChangeJson': rowChangeJson, 'templateName': templateName});
    }
}