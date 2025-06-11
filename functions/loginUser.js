exports.handler = async (event, context) => {
    if (event.httpMethod !== 'POST') {
      return { statusCode: 405, body: 'Method Not Allowed' };
    }
  
    const { email, password } = JSON.parse(event.body);
  
    // Simple hardcoded check (for now)
    if (email === 'test@email.com' && password === 'password123') {
      return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Login successful!', token: 'fake-jwt-token' }),
      };
    } else {
      return {
        statusCode: 401,
        body: JSON.stringify({ message: 'Invalid credentials' }),
      };
    }
  };
  