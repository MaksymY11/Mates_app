exports.handler = async (event, context) => {
    if (event.httpMethod !== 'POST') {
      return { statusCode: 405, body: 'Method Not Allowed' };
    }
  
    const { email, password } = JSON.parse(event.body);
  
    // Very simple example - you should store data into a database here
    console.log('Registering user:', email);
  
    // For now, just return success
    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'User registered successfully!' }),
    };
  };