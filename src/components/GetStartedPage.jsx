import React, { useState } from 'react';
    import { Steps, Button, Typography, Form, Input, Checkbox, message } from 'antd';
    import { useNavigate } from 'react-router-dom';

    const { Step } = Steps;
    const { Title, Paragraph } = Typography;

    const GetStartedPage = ({ supabase, session }) => {
      const [current, setCurrent] = useState(0);
      const [companyType, setCompanyType] = useState(null);
      const [newCompanyData, setNewCompanyData] = useState({});
      const [existingCompanyData, setExistingCompanyData] = useState({});
      const [legalAgreement, setLegalAgreement] = useState(false);
      const navigate = useNavigate();

      const steps = [
        {
          title: 'Welcome',
          content: (
            <div>
              <Title level={2}>Welcome to Our CRM!</Title>
              <Paragraph>Let's get you started with a quick setup.</Paragraph>
            </div>
          ),
        },
        {
          title: 'Company Type',
          content: (
            <div>
              <Title level={3}>Are you joining an existing team or creating a new one?</Title>
              <div className="flex space-x-4 mt-4">
                <Button type="primary" onClick={() => setCompanyType('new')}>
                  New Team/Company
                </Button>
                <Button type="primary" onClick={() => setCompanyType('existing')}>
                  Existing Team/Company
                </Button>
              </div>
            </div>
          ),
        },
        {
          title: 'Company Details',
          content: (
            <div>
              {companyType === 'new' && (
                <Form
                  layout="vertical"
                  onFinish={(values) => setNewCompanyData(values)}
                >
                  <Form.Item
                    label="Company Name"
                    name="companyName"
                    rules={[{ required: true, message: 'Please enter company name' }]}
                  >
                    <Input />
                  </Form.Item>
                  <Form.Item
                    label="Company Code"
                    name="companyCode"
                    rules={[{ required: true, message: 'Please enter company code' }]}
                  >
                    <Input />
                  </Form.Item>
                </Form>
              )}
              {companyType === 'existing' && (
                <Form
                  layout="vertical"
                  onFinish={(values) => setExistingCompanyData(values)}
                >
                  <Form.Item
                    label="Company Code"
                    name="companyCode"
                    rules={[{ required: true, message: 'Please enter company code' }]}
                  >
                    <Input />
                  </Form.Item>
                  <Form.Item
                    label="Supervisor Code"
                    name="supervisorCode"
                    rules={[{ required: true, message: 'Please enter supervisor code' }]}
                  >
                    <Input />
                  </Form.Item>
                </Form>
              )}
            </div>
          ),
        },
        {
          title: 'Legal Agreement',
          content: (
            <div>
              <Title level={3}>Legal Agreement</Title>
              <Paragraph>
                Please read and accept the terms and conditions to proceed.
              </Paragraph>
              <Checkbox
                checked={legalAgreement}
                onChange={(e) => setLegalAgreement(e.target.checked)}
              >
                I agree to the terms and conditions.
              </Checkbox>
            </div>
          ),
        },
      ];

      const next = () => {
        if (current === 2) {
          if (companyType === 'new' && Object.keys(newCompanyData).length === 0) {
            message.error('Please fill in the new company details.');
            return;
          }
          if (companyType === 'existing' && Object.keys(existingCompanyData).length === 0) {
            message.error('Please fill in the existing company details.');
            return;
          }
        }
        setCurrent(current + 1);
      };

      const prev = () => {
        setCurrent(current - 1);
      };

      const handleFinish = async () => {
        if (!legalAgreement) {
          message.error('Please accept the legal agreement to proceed.');
          return;
        }

        try {
          let companyId = null;
          if (companyType === 'new') {
            const { data: companyData, error: companyError } = await supabase
              .from('companies')
              .insert([
                {
                  name: newCompanyData.companyName,
                  code: newCompanyData.companyCode,
                },
              ])
              .select()
              .single();

            if (companyError) {
              console.error('Error creating company:', companyError);
              message.error('Failed to create company.');
              return;
            }
            companyId = companyData.id;
          } else if (companyType === 'existing') {
            const { data: companyData, error: companyError } = await supabase
              .from('companies')
              .select('id')
              .eq('code', existingCompanyData.companyCode)
              .single();

            if (companyError || !companyData) {
              console.error('Error fetching company:', companyError);
              message.error('Invalid company code.');
              return;
            }
            companyId = companyData.id;
          }

          const { error: userProfileError } = await supabase
            .from('user_profiles')
            .insert([
              {
                user_id: session.user.id,
                company_id: companyId,
                supervisor_code: existingCompanyData.supervisorCode,
                onboarded: true,
                legal_agreement: legalAgreement,
              },
            ]);

          if (userProfileError) {
            console.error('Error creating user profile:', userProfileError);
            message.error('Failed to create user profile.');
            return;
          }

          message.success('Onboarding completed successfully!');
          navigate('/dashboard');
        } catch (error) {
          console.error('Error during onboarding:', error);
          message.error('An error occurred during onboarding.');
        }
      };

      return (
        <div className="max-w-2xl mx-auto mt-10">
          <Steps current={current}>
            {steps.map((item) => (
              <Step key={item.title} title={item.title} />
            ))}
          </Steps>
          <div className="mt-8">
            {steps[current].content}
            <div className="mt-8 flex justify-between">
              {current > 0 && (
                <Button onClick={prev}>
                  Previous
                </Button>
              )}
              {current < steps.length - 1 && (
                <Button type="primary" onClick={next}>
                  Next
                </Button>
              )}
              {current === steps.length - 1 && (
                <Button type="primary" onClick={handleFinish}>
                  Finish
                </Button>
              )}
            </div>
          </div>
        </div>
      );
    };

    export default GetStartedPage;
