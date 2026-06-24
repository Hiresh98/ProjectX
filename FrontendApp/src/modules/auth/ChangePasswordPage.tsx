import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Paper from '@mui/material/Paper';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import {
  changePasswordSchema,
  type ChangePasswordValues,
} from './auth.schemas';
import { useChangePasswordMutation } from '@/services/authApi';
import { getApiErrorMessage } from '@/utils/getApiErrorMessage';

export function ChangePasswordPage() {
  const [changePassword, { isLoading, isSuccess, error }] =
    useChangePasswordMutation();

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<ChangePasswordValues>({
    resolver: zodResolver(changePasswordSchema),
    defaultValues: {
      currentPassword: '',
      newPassword: '',
      confirmPassword: '',
    },
  });

  const onSubmit = handleSubmit(async (values) => {
    await changePassword({
      currentPassword: values.currentPassword,
      newPassword: values.newPassword,
    }).unwrap();
    reset();
  });

  return (
    <Box sx={{ maxWidth: 480 }}>
      <Typography variant="h5" gutterBottom sx={{ fontWeight: 700 }}>
        Change password
      </Typography>
      <Paper sx={{ p: 3 }}>
        <Box component="form" onSubmit={(e) => void onSubmit(e)} noValidate>
          {isSuccess && (
            <Alert severity="success" sx={{ mb: 2 }}>
              Password updated.
            </Alert>
          )}
          {error && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {getApiErrorMessage(error)}
            </Alert>
          )}
          <Stack spacing={2}>
            <TextField
              label="Current password"
              type="password"
              autoComplete="current-password"
              fullWidth
              error={Boolean(errors.currentPassword)}
              helperText={errors.currentPassword?.message}
              {...register('currentPassword')}
            />
            <TextField
              label="New password"
              type="password"
              autoComplete="new-password"
              fullWidth
              error={Boolean(errors.newPassword)}
              helperText={errors.newPassword?.message}
              {...register('newPassword')}
            />
            <TextField
              label="Confirm new password"
              type="password"
              autoComplete="new-password"
              fullWidth
              error={Boolean(errors.confirmPassword)}
              helperText={errors.confirmPassword?.message}
              {...register('confirmPassword')}
            />
            <Button type="submit" variant="contained" disabled={isLoading}>
              {isLoading ? 'Saving…' : 'Update password'}
            </Button>
          </Stack>
        </Box>
      </Paper>
    </Box>
  );
}

export default ChangePasswordPage;
