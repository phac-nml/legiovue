# Development Roadmap
What is going to be added. The order is not necessarily the priority in which they will be

1. Test Dataset available and run with profile `test` and `test_full`
    - This will allow the pipeline to be checked by new users to see that it has been correctly installed

2. Parameter validation using nf-core plugin
    - Check that inputs are as expected
    - Better help statement
    - Better version output

3. Investigations Document
    - Downsampling testing
    - Tool testing

4. CI Tests
    - nf-test
    - linting

5. IRIDA-Next requirements
    - Add in needed IRIDA next requirements and plugin

6. Validation dataset and report for releases
    - To make sure everything is working correctly on releases, have a validation report to go along with them

7. Requested updates (or updates we were planning)
    - Filtering out non *Legionella* reads after kraken/bracken
    - Other tool testing
        - For resource/speed/output optimization
