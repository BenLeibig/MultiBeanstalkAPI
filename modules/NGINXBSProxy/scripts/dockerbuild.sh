
set -e
start=`date +%s`

# AWS Region where app should be deployed e.g. `us-east-1`, `eu-central-1`  - could pull from profile
REGION="eu-central-1"

AWS_ACCOUNT_ID=`aws --profile=$AWS_PROFILE_NAME sts get-caller-identity --output text --query 'Account'`

# Hash of Docker container commit for better identification
SHA1=$start

if [ -z "$AWS_PROFILE_NAME" ]; then
  exit 1
fi

if [ -z "$NAME" ]; then
  exit 1
fi


if [ -z "$STAGE" ]; then
  exit 1
fi

if [ -z "$REGION" ]; then
    exit 1
fi

if [ -z "$SHA1" ]; then
    exit 1
fi



EB_BUCKET=crvshlab-beanstalk-deployment-files
ENV=$NAME-$STAGE
VERSION=$SHA1
ZIP=$VERSION.zip

echo Deploying $NAME to environment $STAGE, region: $REGION, version: $VERSION, bucket: $EB_BUCKET using profile $AWS_PROFILE_NAME

echo "Configuring AWS"
aws configure set default.output json
aws configure set default.region $REGION
# Login to AWS Elastic Container Registry
eval $(aws --profile=$AWS_PROFILE_NAME --region=$REGION ecr get-login --no-include-email | sed 's|https://||')
# Build the image
docker build -t $NAME:$VERSION .
# Tag it
docker tag $NAME:$VERSION $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$NAME:$VERSION
# Push to AWS Elastic Container Registry
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$NAME:$VERSION
cp Dockerrun.aws.json.template Dockerrun.aws.json
# Replace the <AWS_ACCOUNT_ID> with your ID
sed -i='' "s/<ACCOUNT_ID>/$AWS_ACCOUNT_ID/" Dockerrun.aws.json
# Replace the <NAME> w:ith the your name
sed -i='' "s/<NAME>/$NAME/" Dockerrun.aws.json
# Replace the <REGION> with the selected region
sed -i='' "s/<REGION>/$REGION/" Dockerrun.aws.json
# Replace the <TAG> with the your version number
sed -i='' "s/<VERSION>/$VERSION/" Dockerrun.aws.json
# Replaces the port number with your port_number
sed -i='' "s/<PORT>/$PORT/" Dockerrun.aws.json
# Zip up the Dockerrun file
zip -r $ZIP Dockerrun.aws.json

# Send zip to S3 Bucket
aws --profile=$AWS_PROFILE_NAME --region=$REGION s3 cp $ZIP s3://$EB_BUCKET/$ZIP
# Create a new application version with the zipped up Dockerrun file
aws --profile=$AWS_PROFILE_NAME --region=$REGION elasticbeanstalk create-application-version --application-name $NAME --version-label $VERSION --source-bundle S3Bucket=$EB_BUCKET,S3Key=$ZIP

# Update the environment to use the new application version
aws --profile=$AWS_PROFILE_NAME --region=$REGION elasticbeanstalk update-environment --environment-name $ENV --version-label $VERSION

end=`date +%s`

echo Deploy ended with success! Time elapsed: $((end-start)) seconds
