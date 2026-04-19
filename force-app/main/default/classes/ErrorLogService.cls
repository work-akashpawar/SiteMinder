/**
 * Service class for structured error logging to Error_Log__c object
 * Provides methods to log errors from batch and queueable jobs
 */
public with sharing class ErrorLogService {
    
    /**
     * Logs a single error to Error_Log__c
     * @param processName Name of the process/class where error occurred
     * @param errorMessage The error message
     * @param recordId Optional record Id associated with the error
     * @param stackTrace Optional stack trace
     * @param severity Optional severity level (defaults to 'Medium')
     */
    public static void logError(
        String processName, 
        String errorMessage, 
        String recordId, 
        String stackTrace, 
        String severity
    ) {
        try {
            Error_Log__c errorLog = new Error_Log__c(
                Process_Name__c = processName,
                Error_Message__c = errorMessage,
                Record_Id__c = recordId,
                Stack_Trace__c = stackTrace,
                Severity__c = String.isNotBlank(severity) ? severity : 'Medium'
            );
            
            insert errorLog;
        } catch (Exception e) {
            // Fallback: Log to system debug if error log insert fails
            System.debug(LoggingLevel.ERROR, 'Failed to log error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Original error: ' + errorMessage);
        }
    }
    
    /**
     * Logs multiple errors in bulk
     * @param errors List of error log records to insert
     */
    public static void logErrors(List<Error_Log__c> errors) {
        if (errors == null || errors.isEmpty()) {
            return;
        }
        
        try {
            Database.SaveResult[] results = Database.insert(errors, false);
            
            // Check for failures in bulk insert
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug(LoggingLevel.ERROR, 
                        'Failed to log error at index ' + i + ': ' + results[i].getErrors());
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to bulk log errors: ' + e.getMessage());
        }
    }
    
    /**
     * Creates an error log record from an exception
     * @param processName Name of the process/class
     * @param ex The exception
     * @param recordId Optional record Id
     * @return Error_Log__c record (not yet inserted)
     */
    public static Error_Log__c createErrorLogFromException(
        String processName, 
        Exception ex, 
        String recordId
    ) {
        return new Error_Log__c(
            Process_Name__c = processName,
            Error_Message__c = ex.getMessage(),
            Record_Id__c = recordId,
            Stack_Trace__c = ex.getStackTraceString(),
            Severity__c = ex instanceof DmlException ? 'High' : 'Medium'
        );
    }
    
    /**
     * Logs DML errors from Database.SaveResult
     * @param processName Name of the process/class
     * @param results Database SaveResults
     * @param records Original records that were being updated
     */
    public static void logDmlErrors(
        String processName, 
        Database.SaveResult[] results, 
        List<SObject> records
    ) {
        List<Error_Log__c> errorLogs = new List<Error_Log__c>();
        
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                String recordId = records[i].Id;
                List<String> errorMessages = new List<String>();
                
                for (Database.Error err : results[i].getErrors()) {
                    errorMessages.add(err.getStatusCode() + ': ' + err.getMessage() + 
                                     ' (Fields: ' + String.join(err.getFields(), ', ') + ')');
                }
                
                errorLogs.add(new Error_Log__c(
                    Process_Name__c = processName,
                    Error_Message__c = String.join(errorMessages, '\n'),
                    Record_Id__c = recordId,
                    Severity__c = 'High'
                ));
            }
        }
        
        if (!errorLogs.isEmpty()) {
            logErrors(errorLogs);
        }
    }
    
    /**
     * Queries recent error logs for a specific process
     * @param processName Name of the process to query
     * @param limitCount Number of records to return
     * @return List of error logs
     */
    public static List<Error_Log__c> getRecentErrors(String processName, Integer limitCount) {
        return [
            SELECT Id, Name, Process_Name__c, Error_Message__c, Record_Id__c, 
                   Severity__c, CreatedDate
            FROM Error_Log__c
            WHERE Process_Name__c = :processName
            ORDER BY CreatedDate DESC
            LIMIT :limitCount
        ];
    }
}