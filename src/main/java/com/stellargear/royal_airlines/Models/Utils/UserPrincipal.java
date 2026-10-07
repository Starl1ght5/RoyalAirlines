package com.stellargear.royal_airlines.Models.Utils;

import com.stellargear.royal_airlines.Models.Entities.User;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

/**
 * Envoltura de {@link User} que adapta la entidad al contrato de Spring Security.
 *
 * <p>Se crea en tiempo de peticion y sirve para que los controladores obtengan el identificador
 * del usuario autenticado sin depender de parametros del cliente.</p>
 */
public class UserPrincipal implements UserDetails {

    private final User user;

    /**
     * Envuelve la entidad de usuario.
     *
     * @param user usuario autenticado.
     */
    public UserPrincipal(User user) {
        this.user = user;
    }

    /**
     * Devuelve el identificador del usuario.
     *
     * @return identificador interno del usuario.
     */
    public String getUserID() {
        return user.getUserID();
    }

    /**
     * Permisos del usuario dentro de la aplicacion.
     *
     * @return lista con el rol {@code ROLE_USER}, que habilita {@code hasRole("USER")}.
     */
    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_USER"));
    }

    /**
     * Hash de la contrasena, usado por el proceso de autenticacion.
     *
     * @return hash BCrypt almacenado.
     */
    @Override
    public String getPassword() {
        return user.getPassword();
    }

    /**
     * Nombre de inicio de sesion: en esta aplicacion es el correo, que es el sujeto del JWT.
     *
     * @return correo del usuario.
     */
    @Override
    public String getUsername() {
        return user.getEmail();
    }

    /**
     * Las cuentas locales no tienen fecha de vencimiento.
     *
     * @return siempre {@code true}.
     */
    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    /**
     * Las cuentas locales no se bloquean por intentos fallidos.
     *
     * @return siempre {@code true}.
     */
    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    /**
     * La contrasena no caduca por tiempo, sino por rotacion manual.
     *
     * @return siempre {@code true}.
     */
    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    /**
     * El estado de la cuenta se valida con {@code verified}, no al activar el principal.
     *
     * @return siempre {@code true}.
     */
    @Override
    public boolean isEnabled() {
        return true;
    }
}