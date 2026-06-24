import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Link as RouterLink, useNavigate } from 'react-router-dom';
import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Link from '@mui/material/Link';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import { loginSchema, type LoginValues } from './auth.schemas';
import { useLoginMutation } from '@/services/authApi';
import { useAppDispatch } from '@/store/hooks';
import { setCredentials } from '@/store/authSlice';
import { getDefaultRouteForRoles } from '@/constants/permissions';
import { getApiErrorMessage } from '@/utils/getApiErrorMessage';

export function LoginPage() {
  const navigate = useNavigate();
  const dispatch = useAppDispatch();
  const [login, { isLoading, error }] = useLoginMutation();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: '', password: '' },
  });

  const onSubmit = handleSubmit(async (values) => {
    const result = await login(values).unwrap();
    dispatch(setCredentials(result));
    navigate(getDefaultRouteForRoles(result.user.roles), { replace: true });
  });

  return (
    <Box component="form" onSubmit={(e) => void onSubmit(e)} noValidate>
      <Typography variant="h6" gutterBottom>
        Sign in
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {getApiErrorMessage(error, 'Invalid credentials')}
        </Alert>
      )}

      <Stack spacing={2}>
        <TextField
          label="Email"
          type="email"
          autoComplete="email"
          fullWidth
          error={Boolean(errors.email)}
          helperText={errors.email?.message}
          {...register('email')}
        />
        <TextField
          label="Password"
          type="password"
          autoComplete="current-password"
          fullWidth
          error={Boolean(errors.password)}
          helperText={errors.password?.message}
          {...register('password')}
        />
        <Button
          type="submit"
          variant="contained"
          size="large"
          disabled={isLoading}
        >
          {isLoading ? 'Signing in…' : 'Sign in'}
        </Button>
        <Link component={RouterLink} to="/forgot-password" variant="body2">
          Forgot password?
        </Link>
      </Stack>
    </Box>
  );
}

export default LoginPage;
