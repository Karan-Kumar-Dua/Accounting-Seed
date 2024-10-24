global abstract class AbstractBDCRouter {
    global abstract AbstractBDCConnector getConnectorClass();
    global abstract AbstractBDCConverter getConvertorClass();
    global abstract AbstractBDCTransactionBulk getTransacationBulkProcessorClass();

    public AbstractBDCConnector getConnector(){
        return getConnectorClass();
    }

    public AbstractBDCConverter getConverter(){
        return getConvertorClass();
    }

    public AbstractBDCTransactionBulk getTransacationBulkProcessor(){
        return getTransacationBulkProcessorClass();
    }


}