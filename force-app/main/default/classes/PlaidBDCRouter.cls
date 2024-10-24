public class PlaidBDCRouter extends AbstractBDCRouter{
    public override AbstractBDCConnector getConnectorClass(){
      return new PlaidBDCConnector();
    }
      
    public override AbstractBDCConverter getConvertorClass(){
        return new PlaidBDCConverter();
    }
  
    public override AbstractBDCTransactionBulk getTransacationBulkProcessorClass(){
      return new PlaidBDCTransactionBulk();
    }
  }