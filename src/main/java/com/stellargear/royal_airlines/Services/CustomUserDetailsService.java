package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.Entities.User;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Repositories.UserRepository;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.NonNull;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

/**
 * Busca la cuenta de usuario que corresponde a un correo.
 *
 * <p>Es el punto de entrada que usa Spring Security, tanto en el login con contrasena como al
 * validar un token JWT.</p>
 */
@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;

    /**
     * Carga la cuenta asociada a un correo.
     *
     * @param email correo del usuario.
     * @return principal con los datos y permisos del usuario.
     * @throws UsernameNotFoundException si no existe ninguna cuenta con ese correo.
     */
    @Override
    public UserDetails loadUserByUsername(@NonNull String email) throws UsernameNotFoundException {
        User user = userRepository.searchByEmail(email);

        if (user == null) {
            throw new UsernameNotFoundException("Usuario no encontrado");
        }

        return new UserPrincipal(user);
    }
}