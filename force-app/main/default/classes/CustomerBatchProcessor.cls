/**
 * Name: Akash Pawar
 * Description: Batch Apex class to process large volumes of Customer records
 * Features:
 * - Processes all Customer__c records in batches
 * - Normalizes names and validates emails
 * - Performs bulk updates with error handling
 * - Logs errors to Error_Log__c
 * - Chains Queueable job for summary email
 */
public class CustomerBatchProcessor implements Database.Batchable<SObject>, Database.Stateful {
    
    // Stateful counters
    public Integer totalProcessed = 0;
    public Integer totalSucceeded = 0;
    public Integer totalFailed = 0;
    public List<String> failedRecordIds = new List<String>();
    
    // Configuration
    private String filterCriteria;
    private String recipientEmail;
    
    /**
     * Default constructor - processes all pending customers
     */
    public CustomerBatchProcessor() {
        this('Pending', null);
    }
    
    /**
     * Constructor with email notification
     * @param statusFilter Status to filter customers (default: 'Pending')
     * @param email Email address for summary notification
     */
    public CustomerBatchProcessor(String statusFilter, String email) {
        this.filterCriteria = String.isNotBlank(statusFilter) ? statusFilter : 'Pending';
        this.recipientEmail = email;
    }
    
    /**
     * Start method - Query all customers with specified status
     * @param bc Batch context
     * @return Database.QueryLocator for efficient processing
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, First_Name__c, Last_Name__c, Email__c, Status__c, Processed_Date__c ' +
                      'FROM Customer__c ' +
                      'WHERE Status__c = :filterCriteria ' +
                      'ORDER BY CreatedDate ASC';
        
        return Database.getQueryLocator(query);
    }
    
    /**
     * Execute method - Process each batch of customers
     * @param bc Batch context
     * @param scope List of customers in current batch
     */
    public void execute(Database.BatchableContext bc, List<Customer__c> scope) {
        List<Customer__c> customersToUpdate = new List<Customer__c>();
        List<Error_Log__c> errorLogs = new List<Error_Log__c>();
        

        // Validate and normalize each customer
        for (Customer__c customer : scope) {
            totalProcessed++;
            
            try {
                        integer inrs = 2/0;

                // Validate and normalize customer data
                CustomerDataValidator.ValidationResult result = 
                    CustomerDataValidator.validateAndNormalize(customer);
                
                if (result.isValid) {
                    // Update with normalized data
                    result.normalizedCustomer.Status__c = 'Processed';
                    result.normalizedCustomer.Processed_Date__c = System.now();
                    customersToUpdate.add(result.normalizedCustomer);
                } else {
                    // Mark as failed and log error
                    customer.Status__c = 'Failed';
                    customersToUpdate.add(customer);
                    totalFailed++;
                    failedRecordIds.add(customer.Id);
                    
                    // Create error log
                    errorLogs.add(new Error_Log__c(
                        Process_Name__c = 'CustomerBatchProcessor',
                        Error_Message__c = result.errorMessage,
                        Record_Id__c = customer.Id,
                        Severity__c = 'Medium'
                    ));
                }
            } catch (Exception e) {
                // Handle unexpected errors
                customer.Status__c = 'Failed';
                customersToUpdate.add(customer);
                totalFailed++;
                failedRecordIds.add(customer.Id);
                
                errorLogs.add(ErrorLogService.createErrorLogFromException(
                    'CustomerBatchProcessor', e, customer.Id
                ));
            }
        }
        
        // Perform bulk update with partial success
        if (!customersToUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(customersToUpdate, false);
            
            // Process update results
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    if (customersToUpdate[i].Status__c == 'Processed') {
                        totalSucceeded++;
                    }
                } else {
                    // Log DML errors
                    totalFailed++;
                    String recordId = customersToUpdate[i].Id;
                    
                    if (!failedRecordIds.contains(recordId)) {
                        failedRecordIds.add(recordId);
                    }
                    
                    List<String> errorMessages = new List<String>();
                    for (Database.Error err : results[i].getErrors()) {
                        errorMessages.add(err.getStatusCode() + ': ' + err.getMessage());
                    }
                    
                    errorLogs.add(new Error_Log__c(
                        Process_Name__c = 'CustomerBatchProcessor',
                        Error_Message__c = String.join(errorMessages, '\n'),
                        Record_Id__c = recordId,
                        Severity__c = 'High'
                    ));
                }
            }
        }
        
        // Bulk insert error logs
        if (!errorLogs.isEmpty()) {
            ErrorLogService.logErrors(errorLogs);
        }
    }
    
    /**
     * Finish method - Chain queueable for summary email
     * @param bc Batch context
     */
    public void finish(Database.BatchableContext bc) {
        // Get batch job details
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems,
                   CreatedDate, CompletedDate
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        
        // Chain queueable for email summary
        if (String.isNotBlank(recipientEmail)) {
            System.enqueueJob(new CustomerBatchSummaryQueueable(
                recipientEmail,
                totalProcessed,
                totalSucceeded,
                totalFailed,
                failedRecordIds,
                job
            ));
        }
        
        // Log completion
        System.debug('CustomerBatchProcessor completed');
        System.debug('Total Processed: ' + totalProcessed);
        System.debug('Total Succeeded: ' + totalSucceeded);
        System.debug('Total Failed: ' + totalFailed);
    }
}
