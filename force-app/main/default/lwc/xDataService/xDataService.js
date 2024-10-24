import query from '@salesforce/apex/XDataService.query';
import upsertData from '@salesforce/apex/XDataService.upsertData';
import getRecordsCount from '@salesforce/apex/XDataService.getRecordsCount';

export default class XDataService {
    async soqlQuery(soql){
        return query({'soql': soql});
    }
    async countSoqlQuery(soql){
        return getRecordsCount({'soql': soql});
    }
    async upsertSObjectData(records, recordsToDelete,subqueryRelationshipApiName,subgridParentApiName,subgridDataToDelete){
        return upsertData({'records': records, 'recordsToDelete': recordsToDelete, 'subqueryRelationshipApiName' : subqueryRelationshipApiName,
                        'subgridParentApiName' : subgridParentApiName,'subgridDataToDelete': subgridDataToDelete});
    }
}