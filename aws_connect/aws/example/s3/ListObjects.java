//snippet-sourcedescription:[ListObjects.java demonstrates how to list objects within an Amazon S3 bucket.]
//snippet-keyword:[Java]
//snippet-keyword:[Code Sample]
//snippet-keyword:[Amazon S3]
//snippet-keyword:[listObjectsV2]
//snippet-service:[s3]
//snippet-sourcetype:[full-example]
//snippet-sourcedate:[]
//snippet-sourceauthor:[soo-aws]
/*
   Copyright 2010-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
   This file is licensed under the Apache License, Version 2.0 (the "License").
   You may not use this file except in compliance with the License. A copy of
   the License is located at
    http://aws.amazon.com/apache2.0/
   This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
   CONDITIONS OF ANY KIND, either express or implied. See the License for the
   specific language governing permissions and limitations under the License.
*/
package aws.example.s3;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.client.builder.AwsClientBuilder;
import com.amazonaws.services.s3.model.ListObjectsV2Result;
import com.amazonaws.services.s3.model.S3ObjectSummary;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.auth.AWSStaticCredentialsProvider;
import java.util.List;

/**
 * List objects within an Amazon S3 bucket.
 *
 * This code expects that you have AWS credentials set up per:
 * http://docs.aws.amazon.com/java-sdk/latest/developer-guide/setup-credentials.html
 */
public class ListObjects
{
    public static void main(String[] args)
    {
        final String USAGE = "\n" +
            "To run this example, supply the name of a bucket to list!\n" +
            "\n" +
            "Ex: ListObjects <bucket-name> <access-key> <secret-key> <endpoint> <region> \n";

        if (args.length < 5) {
            System.out.println(USAGE);
            System.exit(1);
        }

        String bucket_name = args[0];
	String accesskey = args[1];
	String secretkey = args[2];
	String endpoint = args[3];
	String region = args[4];

        System.out.format("Objects in S3 bucket %s:\n", bucket_name);
	BasicAWSCredentials awsCreds = new BasicAWSCredentials(accesskey, secretkey);
	AmazonS3 s3Client = AmazonS3ClientBuilder.standard()
                        .withCredentials(new AWSStaticCredentialsProvider(awsCreds))
			.withEndpointConfiguration(new AwsClientBuilder.EndpointConfiguration(endpoint,region))
                        .build();
        ListObjectsV2Result result = s3Client.listObjectsV2(bucket_name);
        List<S3ObjectSummary> objects = result.getObjectSummaries();
        for (S3ObjectSummary os: objects) {
            System.out.println("* " + os.getKey());
        }
    }
}
